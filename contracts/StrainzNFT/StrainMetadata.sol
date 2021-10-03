// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStrainMetadata {
    struct StrainMetadata {
        uint id;
        string prefix;
        string postfix;
        uint dna;
        uint generation;
        uint growRate; // 0-255
        uint lastHarvest;
        uint breedingCost;
    }
}
