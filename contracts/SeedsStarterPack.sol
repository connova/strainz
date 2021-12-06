// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./StrainzMaster.sol";


contract SeedsStarterPack is ERC721Enumerable{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    address budsContract;
    address fourTwentyContract;

    uint priceForPot;
    uint priceForSeedsStarterPack;

    StrainzMaster master;

    mapping(uint => bool) isNFTConsumedToMintStrainzNFT;
    mapping(uint => bool) isPot;
    mapping(address => uint[]) wallet;

    constructor(address buds, address fourTwenty) ERC721("Strainz Starterpack", "Starter") {
        budsContract = buds;
        fourTwentyContract = fourTwenty;
        master = StrainzMaster(msg.sender);
    }

    function buyPot() public {
        IERC20(budsContract).transferFrom(msg.sender, address(this), priceForPot);
        _tokenIdCounter.increment();
         uint potId = _tokenIdCounter.current();
        _mint(msg.sender, potId);
        isPot[potId] = true;
        wallet[msg.sender].push(potId);
    }

    function buySeedsStarterPack(string memory firstNameOfPlant, string memory lastNameOfPlant) public {
        bool hasConsumablePot;
        for (uint i = 0; i < wallet[msg.sender].length; i++) {
            if (isPot[wallet[msg.sender][i]] && !isNFTConsumedToMintStrainzNFT[wallet[msg.sender][i]]) {
                hasConsumablePot = true;
                break;
            }
        }
        require(hasConsumablePot, "Error: You do not have a pot available");
        IERC20(fourTwentyContract).transferFrom(msg.sender, address(this), priceForSeedsStarterPack);
        _tokenIdCounter.increment();
        uint starterPackID = _tokenIdCounter.current();
        _mint(msg.sender, starterPackID);
        uint dna = makeDNA();
        master.mintFromStarter(msg.sender, firstNameOfPlant, lastNameOfPlant, dna);
    }

    function isTokenAPot(uint tokenId) public view returns(bool) {
        require(tokenId <= _tokenIdCounter.current(), "Error: Token doesn't exist");
        return isPot[tokenId];
    }

    function makeDNA() public view returns(uint) {
        uint randomValue = random();
        uint j = randomValue;
        uint length;
        while (j !=0) {
            length++;
            j /= 10;
        }

        while (randomValue > 99999999999999999) {
            randomValue /= 10;
        }

        return randomValue;
    }

    function random() internal view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    }

}