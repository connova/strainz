// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
//maybe we'll have to remove '../node_modules/' once deploying in the 3 lines below
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./StrainzMaster.sol";


contract StrainzAccessory is ERC721Enumerable, IERC721Receiver {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    // accessoryId -> accessoryType (Joint, Sunglasses, Earring, ...)
    mapping(uint => uint) public accessoryTypeByTokenId;
    // accessoryId -> time
    mapping(uint => uint) public timeOfLastAttachment;

    // strainzNFT -> tokenIds
    mapping(uint => uint[]) public accessoriesByStrainId;
    function getAccessoriesByStrainId(uint strainId) public view returns (uint[] memory) {
        return accessoriesByStrainId[strainId];
    }


    uint numberOfAccessoryTypes = 0;
    mapping(uint => uint) public growBonusForType;

    event AccessoryAttached(uint accessoryId, uint strainId);

    StrainzMaster master;
    modifier onlyMaster {
        require(msg.sender == address(master));
        _;
    }

    modifier onlyStrainzNFT {
        require(msg.sender == address(master.strainzNFT()));
        _;
    }

    constructor(address owner) ERC721("Strainz Accessory", "ACCESSORY") {
        master = StrainzMaster(msg.sender);
        createNewAccessory(10, owner);
        createNewAccessory(25, owner);
        createNewAccessory(50, owner);
        createNewAccessory(0, owner); //added a new creation for miscAccessory with a bonus of 0
    }

    // creates new accessory (breeding)
    function mintAccessory(uint typeId, uint strainId) private {
        uint accessoryId = mint(typeId, address(this));
        accessoriesByStrainId[strainId].push(accessoryId);
        timeOfLastAttachment[accessoryId] = block.timestamp;
    }

    // creates new accessory (migration)
    function migrateMint(uint strainId, bool hasJoint, bool hasSunglasses, bool hasEarring, bool hasMisc) public onlyStrainzNFT {
        if (hasMisc) { //added this additional if statement and bool for the miscAccessories - connova
            mintAccessory(4, strainId);
        }
        if (hasJoint) {
            mintAccessory(3, strainId);
        }
        if (hasSunglasses) {
            mintAccessory(2, strainId);
        }
        if (hasEarring) {
            mintAccessory(1, strainId);
        }

    }

    // initial accessories
    function mint(uint typeId, address receiver) private returns (uint){
        require(typeId <= numberOfAccessoryTypes && typeId > 0);
        _tokenIdCounter.increment();
        uint accessoryId = _tokenIdCounter.current();
        _mint(receiver, accessoryId);
        accessoryTypeByTokenId[accessoryId] = typeId;
        return accessoryId;
    }

    // attach accessory on plant
    function attachAccessory(uint accessoryId, uint strainId) public {
        require(ownerOf(accessoryId) == msg.sender);
        require(master.strainzNFT().ownerOf(strainId) == msg.sender);
        // no double accessories
        require(!sameTypeAlreadyAttached(accessoriesByStrainId[strainId], accessoryTypeByTokenId[accessoryId]));

        transferFrom(msg.sender, address(this), accessoryId);
        accessoriesByStrainId[strainId].push(accessoryId);
        timeOfLastAttachment[accessoryId] = block.timestamp;
        emit AccessoryAttached(accessoryId, strainId);
    }

    // detach accessory (compost)
    function detachAccessory(uint accessoryId, uint strainId) private {
        uint[] storage accessories = accessoriesByStrainId[strainId];
        int index = indexOf(accessories, accessoryId);
        require(index >= 0);
        remove(accessories, uint(index));
        _transfer(address(this), master.strainzNFT().ownerOf(strainId), accessoryId);
    }

    function getHarvestableAccessoryAmount(uint strainId, uint timeSinceLastHarvest) public view returns (uint) {
        uint[] memory accessoryIds = getAccessoriesByStrainId(strainId);

        uint accessoryBonus = 0;
        for (uint i = 0; i < accessoryIds.length; i++) {
            uint accessoryType = accessoryTypeByTokenId[accessoryIds[i]];
            uint boost = growBonusForType[accessoryType];
            uint timeOfAttachment = timeOfLastAttachment[accessoryIds[i]];
            if (timeOfAttachment == 0) {
                continue;
            }
            uint attachTime = min(block.timestamp - timeOfAttachment, timeSinceLastHarvest);

            accessoryBonus += attachTime * boost / 1 days;
        }
        return accessoryBonus;
    }


    // detach all (compost)
    function detachAll(uint strainId) public onlyStrainzNFT {
        uint[] memory accessoryIds = accessoriesByStrainId[strainId];
        for (uint i = 0; i < accessoryIds.length; i++) {
            detachAccessory(accessoryIds[i], strainId);
        }
    }


    function sameTypeAlreadyAttached(uint[] storage array, uint newType) private view returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            uint existingType = accessoryTypeByTokenId[array[i]];
            if (existingType == newType) {
                return true;
            }
        }
        return false;
    }

    // generates accessories based on parents/fertilizer
    function breedAccessories(uint strain1Id, uint strain2Id, uint newStrainId) public onlyStrainzNFT {
        uint[] storage strain1Accessories = accessoriesByStrainId[strain1Id];
        uint[] storage strain2Accessories = accessoriesByStrainId[strain2Id];

        for (uint i = 1; i <= numberOfAccessoryTypes; i++) {
            bool hasParent1 = sameTypeAlreadyAttached(strain1Accessories, i);
            bool hasParent2 = sameTypeAlreadyAttached(strain2Accessories, i);
            if (hasParent1 && hasParent2){
                mintAccessory(i, newStrainId);
            }

        }

    }

    function createNewAccessory(uint bonus, address owner) public onlyMaster {
        require(numberOfAccessoryTypes < 10);
        numberOfAccessoryTypes++;
        growBonusForType[numberOfAccessoryTypes] = bonus;
        for (uint i = 0; i < 20; i++) {
            mint(numberOfAccessoryTypes, owner);
        }
    }

    function setAccessoryBonus(uint accessoryType, uint bonus) public onlyMaster {
        growBonusForType[accessoryType] = bonus;
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

    function remove(uint[] storage array, uint index) private {
        if (index >= array.length) {
            return;
        }
        array[index] = array[array.length - 1];
        array.pop();
    }

    function indexOf(uint[] storage array, uint tokenId) private view returns (int) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == tokenId) {
                return int(i);
            }
        }
        return - 1;
    }

    bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;

    function onERC721Received(address, address, uint256, bytes calldata) public pure override returns (bytes4) {
        return ERC721_RECEIVED;
    }
}