// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract CCNFT is ERC721Enumerable, Ownable, ReentrancyGuard {

    using Counters for Counters.Counter;

    Counters.Counter private tokenIdTracker;

    struct TokenSale {
        bool onSale;
        uint256 price;
    }

    // Mappings
    mapping(uint256 => uint256) public values;
    mapping(uint256 => bool) public validValues;
    mapping(uint256 => TokenSale) public tokensOnSale;

    // State Variables
    uint256[] public listTokensOnSale;

    address public fundsCollector;
    address public feesCollector;

    bool public canBuy;
    bool public canClaim;
    bool public canTrade;

    uint256 public totalValue;
    uint256 public maxValueToRaise;

    uint16 public buyFee;
    uint16 public tradeFee;

    uint16 public maxBatchCount;
    uint32 public profitToPay;

    IERC20 public fundsToken;

    // Events
    event Buy(address indexed buyer, uint256 indexed tokenId, uint256 value);
    event Claim(address indexed claimer, uint256 indexed tokenId);
    event Trade(address indexed buyer, address indexed seller, uint256 indexed tokenId, uint256 value);
    event PutOnSale(uint256 indexed tokenId, uint256 price);
    event RemoveFromSale(uint256 indexed tokenId);

    // Constructor
    constructor(
        string memory name,
        string memory symbol,
        address _fundsToken,
        address _fundsCollector,
        address _feesCollector,
        uint16 _buyFee,
        uint16 _tradeFee,
        uint16 _maxBatchCount,
        uint32 _profitToPay,
        uint256 _maxValueToRaise
    ) ERC721(name, symbol) {
        require(_fundsToken != address(0), "Funds token address cannot be zero");
        require(_fundsCollector != address(0), "Funds collector address cannot be zero");
        require(_feesCollector != address(0), "Fees collector address cannot be zero");

        fundsToken = IERC20(_fundsToken);
        fundsCollector = _fundsCollector;
        feesCollector = _feesCollector;

        buyFee = _buyFee;
        tradeFee = _tradeFee;
        maxBatchCount = _maxBatchCount;
        profitToPay = _profitToPay;
        maxValueToRaise = _maxValueToRaise;

        canBuy = true;
        canClaim = true;
        canTrade = true;
    }

    // Buy NFTs
    function buy(uint256 value, uint256 amount) external nonReentrant {
        require(canBuy, "Buying is not enabled");
        require(amount > 0 && amount <= maxBatchCount, "Invalid amount");
        require(validValues[value], "Invalid NFT value");
        require(totalValue + (value * amount) <= maxValueToRaise, "Exceeds max value to raise");

        totalValue += value * amount;

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = tokenIdTracker.current();
            values[tokenId] = value;
            _safeMint(msg.sender, tokenId);
            emit Buy(msg.sender, tokenId, value);
            tokenIdTracker.increment();
        }

        uint256 totalCost = value * amount;
        uint256 totalFee = (totalCost * buyFee) / 10000;

        if (!fundsToken.transferFrom(msg.sender, fundsCollector, totalCost)) {
            revert("Cannot send funds tokens");
        }

        if (!fundsToken.transferFrom(msg.sender, feesCollector, totalFee)) {
            revert("Cannot send fees tokens");
        }
    }

    // Claim NFTs
    function claim(uint256[] calldata listTokenId) external nonReentrant {
        require(canClaim, "Claiming is not enabled");
        require(listTokenId.length > 0 && listTokenId.length <= maxBatchCount, "Invalid token list");

        uint256 claimValue = 0;

        for (uint256 i = 0; i < listTokenId.length; i++) {
            uint256 tokenId = listTokenId[i];
            require(_exists(tokenId), "Token does not exist");
            require(ownerOf(tokenId) == msg.sender, "Only owner can claim");

            claimValue += values[tokenId];
            values[tokenId] = 0;

            TokenSale storage tokenSale = tokensOnSale[tokenId];
            tokenSale.onSale = false;
            tokenSale.price = 0;

            _removeFromArray(listTokensOnSale, tokenId);
            _burn(tokenId);
            emit Claim(msg.sender, tokenId);
        }

        totalValue -= claimValue;
        uint256 payout = claimValue + ((claimValue * profitToPay) / 10000);

        if (!fundsToken.transfer(msg.sender, payout)) {
            revert("Cannot send funds");
        }
    }

    // Trade NFTs
    function trade(uint256 tokenId) external nonReentrant {
        require(canTrade, "Trading is not enabled");
        require(_exists(tokenId), "Token does not exist");
        address owner = ownerOf(tokenId);
        require(owner != msg.sender, "Buyer is the seller");

        TokenSale storage tokenSale = tokensOnSale[tokenId];
        require(tokenSale.onSale, "Token not on sale");

        uint256 price = tokenSale.price;
        uint256 fee = (price * tradeFee) / 10000;

        if (!fundsToken.transferFrom(msg.sender, owner, price)) {
            revert("Cannot send funds");
        }

        if (!fundsToken.transferFrom(msg.sender, feesCollector, fee)) {
            revert("Cannot send fees tokens");
        }

        emit Trade(msg.sender, owner, tokenId, price);

        _safeTransfer(owner, msg.sender, tokenId, "");

        tokenSale.onSale = false;
        tokenSale.price = 0;
        _removeFromArray(listTokensOnSale, tokenId);
    }

    // Put NFT on Sale
    function putOnSale(uint256 tokenId, uint256 price) external {
        require(canTrade, "Trading is not enabled");
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        TokenSale storage tokenSale = tokensOnSale[tokenId];
        tokenSale.onSale = true;
        tokenSale.price = price;

        _addToArray(listTokensOnSale, tokenId);
        emit PutOnSale(tokenId, price);
    }

    // Remove NFT from Sale
    function removeFromSale(uint256 tokenId) external {
        require(canTrade, "Trading is not enabled");
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        TokenSale storage tokenSale = tokensOnSale[tokenId];
        require(tokenSale.onSale, "Token is not on sale");

        tokenSale.onSale = false;
        tokenSale.price = 0;

        _removeFromArray(listTokensOnSale, tokenId);
        emit RemoveFromSale(tokenId);
    }

    // Private utility functions for array management
    function _addToArray(uint256[] storage array, uint256 value) private {
        if (_find(array, value) == array.length) {
            array.push(value);
        }
    }

    function _removeFromArray(uint256[] storage array, uint256 value) private {
        uint256 index = _find(array, value);
        if (index < array.length) {
            array[index] = array[array.length - 1];
            array.pop();
        }
    }

    function _find(uint256[] storage array, uint256 value) private view returns (uint256) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return i;
            }
        }
        return array.length;
    }
}
