// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./StrainzNFT/StrainzNFT.sol";
import "./StrainzTokens/StrainzToken.sol";
import "./StrainzTokens/SeedzToken.sol";
import "./StrainzAccessory.sol";
import "./StrainzMarketplace.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract StrainzMaster is Ownable {

    StrainzNFT public strainzNFT = new StrainzNFT();
    StrainzToken public strainzToken = new StrainzToken();
    SeedzToken public seedzToken = new SeedzToken(msg.sender);
    StrainzAccessory public strainzAccessory = new StrainzAccessory(msg.sender);
    StrainzMarketplace public strainzMarketplace = new StrainzMarketplace();
    
    //data structure for manager system begins - connova

    mapping(address => bool) isManager;

    struct Operation {
        string functionName;
        string input;
        uint operationId;
        uint tally;
    }
    Operation[] operations;
    uint operationIds;

    modifier managersOnly {
        require(isManager[msg.sender], "Error: you are not a manager");
        _;
    }

    // data structure for managers ends - connova

    constructor() {
        isManager[msg.sender] = true;
    }

    bool migrationActive = true;

    function migrate() public {
        require(migrationActive);
        uint amountToHarvest = strainzNFT.migrate(msg.sender);
        strainzToken.migrateMint(msg.sender, amountToHarvest);
    }

    function setMigration(bool active) public onlyOwner {
        migrationActive = active;
    }

    function setNewOwner(address newOwner) public {
        transferOwnership(newOwner);
    }

    function addManager(address newManager) public onlyOwner {
        require(!isManager[newManager], "Error: the address is already a manager");
        isManager[newManager] = true;
    }

    function removeManager(address manager) public onlyOwner {
        require(isManager[manager], "Error: that address is already not a manager");
        require(manager != owner(), "Error: the owner cannot be removed");
        isManager[manager] = false;
    }

    function isUserManager(address user) public view returns(bool userIsManager) {
        return isManager[user];
    }

    function setGrowFertilizerDetails(uint newCost, uint newBoost) public onlyOwner {
        seedzToken.setGrowFertilizerDetails(newCost, newBoost);
    }

    function setBreedFertilizerCost(uint newBreedFertilizerCost) public onlyOwner {
        strainzNFT.setBreedFertilizerCost(newBreedFertilizerCost);
    }
    function setBreedingCostFactor(uint newBreedingCostFactor) public onlyOwner {
        strainzNFT.setBreedingCostFactor(newBreedingCostFactor);
    }

    function createNewAccessory(uint bonus) public onlyOwner {
        strainzAccessory.createNewAccessory(bonus, msg.sender);
    }

    function setAccessoryBonus(uint accessoryType, uint bonus) public onlyOwner {
        strainzAccessory.setAccessoryBonus(accessoryType, bonus);
    }

    function setWateringPenalty(uint newPenalty) public onlyOwner {
        strainzNFT.setWateringPenalty(newPenalty);
    }

    function setGrowFactor(uint newGrowFactor) public onlyOwner {
        strainzNFT.setGrowFactor(newGrowFactor);
    }

    function setCompostFactor(uint newCompostFactor) public onlyOwner {
        strainzNFT.setCompostFactor(newCompostFactor);
    }

    function blacklistCheaters(uint[] calldata tokens, address[] calldata users) public onlyOwner {
        strainzNFT.blacklistCheaters(tokens, users);
    }

    function addSeedzPool(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        seedzToken.add(_allocPoint, _lpToken, _withUpdate);
    }
    function setSeedzPool(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        seedzToken.set(_pid, _allocPoint, _withUpdate);
    }

    function setSeedzPerBlock(uint _seedzPerBlock) public onlyOwner {
        seedzToken.setSeedzPerBlock(_seedzPerBlock);
    }
    function mintPromotion(address receiver, string memory prefix, string memory postfix, uint dna) public onlyOwner {
        strainzNFT.mintPromotion(receiver, prefix, postfix, dna);
    }

    function setMarketplaceFee(uint newFee) public onlyOwner {
        strainzMarketplace.setMarketplaceFee(newFee);
    }
}
