// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "../StrainzNFT/StrainMetadata.sol";

abstract contract IStrainzV1 is IERC721Enumerable, IStrainMetadata {
    function harvestAll() public virtual;
    mapping(uint => StrainMetadata) public strainData;
}
