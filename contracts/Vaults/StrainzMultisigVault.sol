// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../StrainzMaster.sol";
import "../StrainzNFT/StrainzNFT.sol";

contract StrainzMultisigVault is IERC721Receiver, IStrainMetadata {

    StrainzMaster master;

    enum ProposalType {
        WithdrawBudz, WithdrawNFT, Breed
    }

    struct Proposal {
        uint id;
        ProposalType proposalType;
        address proposer;
        address receiver;
        uint amount;
        uint tokenId;
        uint breedId1;
        uint breedId2;
        address[] signers;
        bool executed;
    }

    event ProposalCreated(uint proposalId);
    event ProposalSigned(uint proposalId);
    event ProposalExecuted(uint proposalId);

    uint public vaultId;
    string public name;

    uint public  minSignersNeeded;
    address[] public signers;
    mapping(address => string) public signerNames;

    function getSigners() public view returns (address[] memory) {
        return signers;
    }

    function getSignersForProposal(uint proposalId) public view returns (address[] memory) {
        return proposals[proposalId].signers;
    }

    uint public numberOfProposals = 0;
    mapping(uint => Proposal) public proposals;

    constructor(StrainzMaster _master, uint _vaultId, string memory _name, uint _minSignersNeeded, address[] memory _signers, string[] memory _names) {
        require(_minSignersNeeded <= _signers.length && _minSignersNeeded > 1 && _signers.length > 1 && bytes(_name).length > 0 && _names.length == _signers.length);
        for (uint i = 0; i < _signers.length; i++) {
            signers.push(_signers[i]);
            signerNames[_signers[i]] = _names[i];
        }
        minSignersNeeded = _minSignersNeeded;
        name = _name;
        vaultId = _vaultId;
        master = _master;
    }

    function harvest() public {
        require(isSigner(msg.sender));
        master.strainzNFT().harvestAndWaterAll();
    }


    function proposeWithdrawal(address receiver, uint tokenIdOrAmount, bool nft) public {
        require(isSigner(msg.sender));
        address[] memory proposalSigners = new address[](1);
        proposalSigners[0] = msg.sender;
        Proposal memory newProposal;
        if (nft) {
            newProposal = Proposal(
                numberOfProposals, ProposalType.WithdrawNFT, msg.sender, receiver, 0, tokenIdOrAmount, 0, 0, proposalSigners, false
            );
        } else {
            newProposal = Proposal(
                numberOfProposals, ProposalType.WithdrawBudz, msg.sender, receiver, tokenIdOrAmount, 0, 0, 0, proposalSigners, false
            );
        }

        proposals[numberOfProposals] = newProposal;
        emit ProposalCreated(newProposal.id);
        numberOfProposals++;
    }

    function proposeBreed(uint breedId1, uint breedId2) public {
        require(isSigner(msg.sender));
        address[] memory proposalSigners = new address[](1);
        proposalSigners[0] = msg.sender;
        Proposal memory newProposal;
        newProposal = Proposal(
            numberOfProposals, ProposalType.Breed, msg.sender, address(0), 0, 0, breedId1, breedId2, proposalSigners, false
        );

        proposals[numberOfProposals] = newProposal;
        emit ProposalCreated(newProposal.id);
        numberOfProposals++;
    }


    function signProposal(uint proposalId) public {
        require(isSigner(msg.sender));
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed);
        require(!signerInArray(msg.sender, proposal.signers));
        proposal.signers.push(msg.sender);

        emit ProposalSigned(proposal.id);

        if (proposal.signers.length >= minSignersNeeded) {
            executeProposal(proposal);
        }

    }

    function executeProposal(Proposal storage proposal) private {
        if (proposal.proposalType == ProposalType.WithdrawBudz) {
            master.strainzToken().transfer(proposal.receiver, proposal.amount);
        } else if (proposal.proposalType == ProposalType.WithdrawNFT) {
            master.strainzNFT().safeTransferFrom(address(this), proposal.receiver, proposal.tokenId);
        } else if (proposal.proposalType == ProposalType.Breed) {
            StrainzNFT.StrainMetadata memory strain1 = getStrain(proposal.breedId1);
            StrainzNFT.StrainMetadata memory strain2 = getStrain(proposal.breedId2);
            uint cost = max(strain1.breedingCost, strain2.breedingCost);
            master.strainzToken().approve(address(master.strainzToken()), cost);
            master.strainzNFT().breed(strain1.id, strain2.id, false); // TODO: fertilizer in vault
        }
        proposal.executed = true;
        emit ProposalExecuted(proposal.id);
    }

    function getStrain(uint strainId) private view returns (StrainMetadata memory) {
        (uint id,
        string memory prefix,
        string memory postfix,
        uint dna,
        uint generation,
        uint growRate, // 0-255
        uint lastHarvest,
        uint breedingCost) = master.strainzNFT().strainData(strainId);
        return StrainMetadata(id, prefix, postfix, dna, generation, growRate, lastHarvest, breedingCost);
    }

    function max(uint a, uint b) private pure returns (uint) {
        if (a > b) {
            return a;
        } else return b;
    }

    function signerInArray(address signer, address[] memory signerArray) private pure returns (bool) {
        for (uint i = 0; i < signerArray.length; i++) {
            if (signerArray[i] == signer) {
                return true;
            }
        }
        return false;
    }

    function isSigner(address signer) private view returns (bool) {
        return signerInArray(signer, signers);
    }


    bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;

    function onERC721Received(address, address, uint256, bytes calldata) public pure override returns (bytes4) {
        return ERC721_RECEIVED;
    }

}
