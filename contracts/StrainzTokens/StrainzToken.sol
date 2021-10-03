// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../StrainzNFT/StrainzNFT.sol";

contract StrainzToken is ERC20 {
    StrainzMaster master;


    constructor()  ERC20("Strainz", "STRAINZ") {
        master = StrainzMaster(msg.sender);
    }
    modifier onlyMaster() {
        require(msg.sender == address(master));
        _;
    }
    modifier onlyStrainzNFT {
        require(msg.sender == address(master.strainzNFT()));
        _;
    }

    modifier onlyMarketplace {
        require(msg.sender == address(master.strainzMarketplace()));
        _;
    }

    function decimals() public pure override returns(uint8) {
        return 0;
    }

    function harvestMint(address receiver, uint amount) public onlyStrainzNFT {
        _mint(receiver, amount);
    }

    function migrateMint(address receiver, uint amount) public onlyMaster {
        _mint(receiver, amount);
    }

    function breedBurn(address account, uint amount) public onlyStrainzNFT {
        _burn(account, amount);
    }

    function waterBurn(address account, uint amount) public onlyStrainzNFT {
        _burn(account, amount);
    }

    function marketPlaceBurn(address account, uint amount) public onlyMarketplace {
        _burn(account, amount);
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount);
    }



}
