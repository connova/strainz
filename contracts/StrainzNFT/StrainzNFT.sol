// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./StrainzDNA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../StrainzMaster.sol";
import "../v1/IStrainzV1.sol";
import "./StrainMetadata.sol";

contract StrainzNFT is ERC721Enumerable, StrainzDNA, IStrainMetadata {


    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    event Minted(uint tokenId);
    event Breed(uint parent1, uint parent2, uint child);
    event Composted(uint tokenId);


    uint public wateringPenaltyPerDay = 10; // %
    uint public growFactor = 255;
    uint public compostFactor = 100;
    uint public breedingCostFactor = 5;
    uint public breedFertilizerCost = 1000e18;


    mapping(uint => StrainMetadata) public strainData;

    StrainzMaster master;

    modifier onlyMaster {
        require(msg.sender == address(master));
        _;
    }

    constructor() ERC721("Strainz", "STRAINZ") {
        master = StrainzMaster(msg.sender);
    }
    function _baseURI() internal pure override returns (string memory) {
        return "https://api.v2.strainz.tech/strain/";
    }

    function mintTo(address receiver, string memory prefix, string memory postfix, uint dna, uint generation, uint growRate) private returns (uint) {
        _tokenIdCounter.increment();
        uint tokenId = _tokenIdCounter.current();
        _mint(receiver, tokenId);
        strainData[tokenId] = StrainMetadata(tokenId, prefix, postfix, dna, generation, growRate, block.timestamp, growRate * breedingCostFactor);
        emit Minted(tokenId);
        return tokenId;
    }

    // mint promotional unique strainz (will get custom images)
    function mintPromotion(address receiver, string memory prefix, string memory postfix, uint dna) public onlyMaster {
        mintTo(receiver, prefix, postfix, dna, 0, 255);
    }

    // breed two strainz
    function breed(uint _first, uint _second, bool breedFertilizer) public {
        require(ownerOf(_first) == msg.sender && ownerOf(_second) == msg.sender);
        StrainMetadata storage strain1 = strainData[_first];
        StrainMetadata storage strain2 = strainData[_second];

        uint strainzCost = (strain1.breedingCost + strain2.breedingCost) / 2;

        // Burn cost
        master.strainzToken().breedBurn(msg.sender, strainzCost);

        uint newStrainId = mixBreedMint(strain1, strain2, breedFertilizer);
        uint averageGrowRate = (strain1.growRate + strain2.growRate) / 2;
        // Burn fertilizer cost
        if (breedFertilizer && averageGrowRate >= 128) {
            master.seedzToken().breedBurn(msg.sender, breedFertilizerCost);
            master.strainzAccessory().breedAccessories(strain1.id, strain2.id, newStrainId);
        }


        emit Breed(strain1.id, strain2.id, newStrainId);

    }

    function mixBreedMint(StrainMetadata storage strain1, StrainMetadata storage strain2, bool breedFertilizer) private returns (uint) {
        uint newDNA = mixDNA(strain1.dna, strain2.dna);
        uint generation = max(strain1.generation, strain2.generation) + 1;

        bool mix = block.number % 2 == 0;

        strain1.breedingCost = strain1.breedingCost + strain1.growRate * breedingCostFactor;
        strain2.breedingCost = strain2.breedingCost + strain2.growRate * breedingCostFactor;

        return mintTo(
            msg.sender,
            mix ? strain1.prefix : strain2.prefix,
            mix ? strain2.postfix : strain1.postfix,
            newDNA, generation,
            mixStat(strain1.growRate, strain2.growRate, breedFertilizer)
        );
    }


    function compost(uint strainId) public {
        require(ownerOf(strainId) == msg.sender);
        StrainMetadata storage strain = strainData[strainId];
        master.strainzAccessory().detachAll(strainId);
        _burn(strainId);
        master.seedzToken().compostMint(msg.sender, strain.growRate * 1e18 * compostFactor / 100);
        emit Composted(strainId);
    }

    function getWateringCost(uint tokenId) public view returns (uint) {
        StrainMetadata storage strain = strainData[tokenId];
        uint currentGrowRate = getCurrentGrowRateForPlant(tokenId);

        uint diff = strain.growRate - currentGrowRate;

        uint amountOfPlants = balanceOf(ownerOf(tokenId));
        uint penalty = 1;
        if (amountOfPlants > 250) {
            penalty = 9;
        } else if (amountOfPlants > 200) {
            penalty = 8;
        } else if (amountOfPlants > 100) {
            penalty = 7;
        } else if (amountOfPlants > 50) {
            penalty = 5;
        } else if (amountOfPlants > 10) {
            penalty = 3;
        } else if (amountOfPlants > 5) {
            penalty = 2;
        }

        return penalty * diff;
    }

    function harvestAndWaterAll() public {
        uint numberOfTokens = balanceOf(msg.sender);
        require(numberOfTokens > 0);
        uint sum = 0;
        for (uint i = 0; i < numberOfTokens; i++) {
            StrainMetadata storage strain = strainData[tokenOfOwnerByIndex(msg.sender, i)];
            sum += harvestableAmount(strain.id) - getWateringCost(strain.id);
            strain.lastHarvest = block.timestamp;
        }
        master.strainzToken().harvestMint(msg.sender, sum);
    }


    function harvestableAmount(uint tokenId) public view returns (uint) {
        StrainMetadata storage strain = strainData[tokenId];
        uint timeSinceLastHarvest = block.timestamp - strain.lastHarvest;

        uint fertilizerBonus = master.seedzToken().getHarvestableFertilizerAmount(tokenId, strain.lastHarvest);

        uint accessoryBonus = master.strainzAccessory().getHarvestableAccessoryAmount(tokenId, timeSinceLastHarvest);

        uint accumulatedAmount = getAccumulatedHarvestAmount(strain);

        return accumulatedAmount + fertilizerBonus + accessoryBonus;
    }

    function getAccumulatedHarvestAmount(StrainMetadata storage strain) private view returns (uint) {
        uint wateringRange = min(block.timestamp - strain.lastHarvest, 9 days);

        uint growRate = strain.growRate * 1647058824;

        uint harvestableSum = (((20 * growRate * wateringRange * 1 days) - (growRate * wateringRange * wateringRange))) / (20 * 1 days * 1 days) / 1000000000;

        uint stagnationSum = 0;
        if (block.timestamp - strain.lastHarvest > 9 days) {
            stagnationSum = (block.timestamp - strain.lastHarvest + 9 days) * growRate * 10 / 100000000000 days;
        }
        return harvestableSum + stagnationSum;
    }

    function getCurrentGrowRateForPlant(uint plantId) public view returns (uint) {
        StrainMetadata storage strain = strainData[plantId];
        uint timeSinceLastWatering = min(block.timestamp - strain.lastHarvest, 9 days);
        return max(16, strain.growRate - (strain.growRate * wateringPenaltyPerDay * timeSinceLastWatering / 100 days));
    }


    function max(uint a, uint b) private pure returns (uint) {
        if (a > b) {
            return a;
        } else return b;
    }

    function min(uint a, uint b) private pure returns (uint) {
        if (a < b) {
            return a;
        } else return b;
    }

    function mixStat(uint rate1, uint rate2, bool breedFertilizer) private pure returns (uint) {
        uint average = (rate1 + rate2) / 2;
        return breedFertilizer ? min(average + 10, 255) : (average > (25 + 16) ? average - 25 : 16);
    }

    mapping(uint => bool) blacklist; // tokenId -> blacklisted
    mapping(address => bool) blacklistedUser; // address -> blacklisted

    function blacklistCheaters(uint[] calldata tokens, address[] calldata users) public onlyMaster {
        for (uint i = 0; i < tokens.length; i++) {
            blacklist[tokens[i]] = true;
        }
        for (uint i = 0; i < users.length; i++) {
            blacklistedUser[users[i]] = true;
        }
    }

    IStrainzV1 strainzV1NFT = IStrainzV1(0x59516426a8BB328d2F546B05421CBc047042e38f);
    IERC20 strainzV1Token = IERC20(0x7F1AddbB144363730a433A21ACDaB7b36F988252);

    function migrate(address user) public onlyMaster returns (uint) {


        uint numberOfStrainz = min(50, strainzV1NFT.balanceOf(user));

        uint sumToHarvest = 0;
        bool userBlacklisted = blacklistedUser[user];
        //migrate NFT
        if (numberOfStrainz > 0) {
            for (uint i = 0; i < numberOfStrainz; i++) {
                uint id = strainzV1NFT.tokenOfOwnerByIndex(user, 0); // always the first token, because it gets transferred
                StrainMetadata memory strain = getV1Strain(id);
                strainzV1NFT.transferFrom(user, address(this), id); // burn v1


                if (!blacklist[id] && !userBlacklisted) {
                    uint timeSinceLastHarvest = block.timestamp - strain.lastHarvest;
                    uint amountToHarvest = (strain.growRate * 255 * timeSinceLastHarvest) / 24 weeks;
                    // old formular
                    sumToHarvest += amountToHarvest;
                    uint migratedId = mintTo(user, strain.prefix, strain.postfix, strain.dna, strain.generation, max(16, strain.growRate));
                    strainData[migratedId].breedingCost = getNewBreedingCost(strain);

                    // accessories
                    bool hasJoint = getGene(strain.dna, 4) == 1;
                    bool hasSunglasses = getGene(strain.dna, 5) == 1;
                    bool hasEarring = getGene(strain.dna, 6) == 1;
                    bool hasMisc = getGene(strain.dna, 7) == 1;  //added this for miscAccessories - connova
                    if (hasJoint || hasSunglasses || hasEarring || hasMisc) {//modified this if statement to incorporate hasMisc bool - connova
                        master.strainzAccessory().migrateMint(migratedId, hasJoint, hasSunglasses, hasEarring, hasMisc);
                    }

                }
            }
        }


        uint amountOfStrainzV1Tokens = strainzV1Token.balanceOf(user);
        strainzV1Token.transferFrom(user, address(this), amountOfStrainzV1Tokens);
        sumToHarvest += amountOfStrainzV1Tokens;

        return userBlacklisted ? 0 : sumToHarvest;
    }

    function getV1Strain(uint strainId) private view returns (StrainMetadata memory) {
        (uint id,
        string memory prefix,
        string memory postfix,
        uint dna,
        uint generation,
        uint growRate, // 0-255
        uint lastHarvest,
        uint breedingCost) = strainzV1NFT.strainData(strainId);

        return StrainMetadata(id, prefix, postfix, dna, generation, max(16, growRate), lastHarvest, breedingCost);
    }

    function getNewBreedingCost(StrainMetadata memory strain) private pure returns (uint) {
        if (strain.breedingCost == 1000) {
            return strain.growRate * 5;
        } else if (strain.breedingCost == 2000) {
            return strain.growRate * 5 * 2;
        } else if (strain.breedingCost == 4000) {
            return strain.growRate * 5 * 3;
        } else if (strain.breedingCost == 8000) {
            return strain.growRate * 5 * 4;
        } else if (strain.breedingCost == 16000) {
            return strain.growRate * 5 * 5;
        } else if (strain.breedingCost == 32000) {
            return strain.growRate * 5 * 6;
        } else {
            return strain.growRate * 5 * 7;
        }
    }

    function setWateringPenalty(uint newPenalty) public onlyMaster {
        wateringPenaltyPerDay = newPenalty;
    }

    function setGrowFactor(uint newGrowFactor) public onlyMaster {
        growFactor = newGrowFactor;
    }

    function setCompostFactor(uint newCompostFactor) public onlyMaster {
        compostFactor = newCompostFactor;
    }

    function setBreedFertilizerCost(uint newBreedFertilizerCost) public onlyMaster {
        breedFertilizerCost = newBreedFertilizerCost;
    }

    function setBreedingCostFactor(uint newBreedingCostFactor) public onlyMaster {
        breedingCostFactor = newBreedingCostFactor;
    }

}