// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../StrainzMaster.sol";
import "./StrainzMultisigVault.sol";


contract StrainzMultisigFactory {
    StrainzMaster master;
    constructor() {
        master = StrainzMaster(msg.sender);
    }

    uint public numberOfVaults = 0;
    mapping(uint => StrainzMultisigVault) public vaults;

    event VaultCreated(uint vaultId, address vaultAddress);


    function createVault(string memory _name, uint _minSignersNeeded, address[] calldata _signers, string[] calldata _names) public {
        StrainzMultisigVault vault = new StrainzMultisigVault(master, numberOfVaults, _name, _minSignersNeeded, _signers, _names);
        vaults[numberOfVaults] = vault;
        emit VaultCreated(numberOfVaults, address(vault));
        numberOfVaults++;
    }
}
