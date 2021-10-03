// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./StrainzTokens/StrainzToken.sol";
import "./StrainzMaster.sol";

contract StrainzMarketplace is IERC721Receiver {
    using Counters for Counters.Counter;
    Counters.Counter private _tradeCounter;
    enum TradeStatus {
        Open, Closed, Cancelled
    }
    struct ERC721Trade {
        uint id;
        address poster;
        address nftContractAddress;
        uint tokenId;
        uint strainzTokenPrice;
        TradeStatus status;
        address buyer;
    }

    event ERC721TradeStatusChange(uint tradeId, TradeStatus status);

    mapping(uint => ERC721Trade) public erc721Trades;
    uint public marketplaceFee = 10;

    StrainzMaster master;
    modifier onlyMaster {
        require(msg.sender == address(master));
        _;
    }
    constructor() {
        master = StrainzMaster(msg.sender);
    }

    function setMarketplaceFee(uint newFee) public onlyMaster {
        marketplaceFee = newFee;
    }

    function getTradeCount() public view returns (uint) {
        return _tradeCounter.current();
    }

    function openERC721Trade(address nftContractAddress, uint tokenId, uint price) public {
        IERC721 nftContract = IERC721(nftContractAddress);
        require(nftContract.ownerOf(tokenId) == msg.sender);
        _tradeCounter.increment();
        nftContract.transferFrom(msg.sender, address(this), tokenId);
        uint id = _tradeCounter.current();
        erc721Trades[id] = ERC721Trade(id, msg.sender, nftContractAddress, tokenId, price, TradeStatus.Open, address(0));

        emit ERC721TradeStatusChange(id, TradeStatus.Open);
    }

    function executeERC721Trade(uint tradeId) public {
        ERC721Trade memory trade = erc721Trades[tradeId];
        require(trade.status == TradeStatus.Open);
        uint marketPlaceShare = trade.strainzTokenPrice * marketplaceFee / 100;

        master.strainzToken().marketPlaceBurn(msg.sender, marketPlaceShare);

        master.strainzToken().transferFrom(msg.sender, trade.poster, trade.strainzTokenPrice - marketPlaceShare);
        IERC721 nftContract = IERC721(trade.nftContractAddress);
        nftContract.safeTransferFrom(address(this), msg.sender, trade.tokenId);

        erc721Trades[tradeId].status = TradeStatus.Closed;
        erc721Trades[tradeId].buyer = msg.sender;
        emit ERC721TradeStatusChange(tradeId, TradeStatus.Closed);
    }

    function cancelERC721Trade(uint tradeId) public {
        ERC721Trade memory trade = erc721Trades[tradeId];
        require(msg.sender == trade.poster);
        require(trade.status == TradeStatus.Open);
        IERC721 nftContract = IERC721(trade.nftContractAddress);
        nftContract.transferFrom(address(this), trade.poster, trade.tokenId);

        erc721Trades[tradeId].status = TradeStatus.Cancelled;
        emit ERC721TradeStatusChange(tradeId, TradeStatus.Cancelled);
    }


    bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;

    function onERC721Received(address, address, uint256, bytes calldata) public pure override returns (bytes4) {
        return ERC721_RECEIVED;
    }


}
