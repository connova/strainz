// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./StrainzNFT/StrainzNFT.sol";
import "./StrainzTokens/StrainzToken.sol";
import "./StrainzTokens/SeedzToken.sol";
import "./StrainzAccessory.sol";
import "./StrainzMarketplace.sol";
import "./SeedsStarterPack.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract StrainzMaster is Ownable {

    StrainzNFT public strainzNFT = new StrainzNFT();
    StrainzToken public strainzToken = new StrainzToken();
    SeedzToken public seedzToken = new SeedzToken(msg.sender);
    StrainzAccessory public strainzAccessory = new StrainzAccessory(msg.sender);
    StrainzMarketplace public strainzMarketplace = new StrainzMarketplace();
    SeedsStarterPack public strainzStarterPack = new SeedsStarterPack(0x058cdF0fF70f19629D4F50faC03610302e746e58, 0x058cdF0fF70f19629D4F50faC03610302e746e58);
    //  NEED TO CHANGE THE 2ND ADDRESS IT IS NOT 420////////////////////////////////////////////////////////////////////////////// added the new contract - connova

    
    //data structure for manager system begins - connova

    mapping(address => bool) isManager;
    
    uint[] setWateringPenaltyInputs;
    mapping(uint => address) setWateringPenaltyCallers;
    uint[] setMarketplaceFeeInputs;
    mapping(uint => address) setMarketplaceFeeCallers;

    modifier onlyManagers {
        require(isManager[msg.sender], "Error: you are not a manager");
        _;
    }

    // data structure for managers ends - connova

    modifier onlyStarter { // added this new modifier for new contract
        require(msg.sender == address(strainzStarterPack), "Error: You are not authorized for this");
        _;
    }

    constructor() {
        isManager[owner()] = true;  //-connova
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

    function setNewOwner(address newOwner) public {//don't need onlyOwner here since transferOwnership() already has it applied
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

    function setWateringPenalty(uint newPenalty) public onlyManagers {
        
        for(uint i=0; i<setWateringPenaltyInputs.length; i++) {
            
            if(setWateringPenaltyInputs[i] == newPenalty) {

                require(setWateringPenaltyCallers[newPenalty] != msg.sender, "Error: double submission by same manager");
                
                strainzNFT.setWateringPenalty(newPenalty);  //I added everything in this function except this line - connova

                if(i != setWateringPenaltyInputs.length - 1) {
                    setWateringPenaltyInputs[i] = setWateringPenaltyInputs[setWateringPenaltyInputs.length -1];
                }

                setWateringPenaltyInputs.pop();
                setWateringPenaltyCallers[newPenalty] = address(0);

            } else {
                
                setWateringPenaltyInputs.push(newPenalty);
                setWateringPenaltyCallers[newPenalty] = msg.sender;

            }
        }

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

    function mintFromStarter(address receiver, string memory prefix, string memory postfix, uint dna) public onlyStarter {
        
        strainzNFT.mintFromStarter(receiver, prefix, postfix, dna);
        
    } //added this function for the new seeds starter pack contract to be able to mint new strainz NFTs

    function setMarketplaceFee(uint newFee) public onlyManagers { 

        for(uint i=0; i<setMarketplaceFeeInputs.length; i++) {
            
            if(setMarketplaceFeeInputs[i] == newFee) {

                require(setMarketplaceFeeCallers[newFee] != msg.sender, "Error: double submission by same manager");
                
                strainzMarketplace.setMarketplaceFee(newFee);   //I added everything in this function except this line - connova

                if(i != setMarketplaceFeeInputs.length - 1) {
                    setMarketplaceFeeInputs[i] = setMarketplaceFeeInputs[setMarketplaceFeeInputs.length -1];
                }  

                setMarketplaceFeeInputs.pop();
                setMarketplaceFeeCallers[newFee] = address(0);
            
            } else {

                setMarketplaceFeeInputs.push(newFee);
                setMarketplaceFeeCallers[newFee] = msg.sender;

            }
        }
    }
}
