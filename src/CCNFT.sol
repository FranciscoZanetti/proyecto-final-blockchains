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

    // EVENTOS
    event Buy(address indexed buyer, uint256 indexed tokenId, uint256 value);
    event Claim(address indexed claimer, uint256 indexed tokenId);
    event Trade(address indexed buyer, address indexed seller, uint256 indexed tokenId, uint256 value);
    event PutOnSale(uint256 indexed tokenId, uint256 price);
    event RemoveFromSale(uint256 indexed tokenId);

    // Estructura del estado de venta de un NFT.
    struct TokenSale {
        bool onSale;
        uint256 price;
    }

    // Biblioteca Counters de OpenZeppelin para manejar contadores de manera segura.
    Counters.Counter private tokenIdTracker;

    // Mapeo del ID de un token (NFT) a un valor específico.
    mapping(uint256 => uint256) public values;

    // Mapeo de un valor a un booleano para indicar si el valor es válido o no.
    mapping(uint256 => bool) public validValues;

    // Mapeo del ID de un token (NFT) a su estado de venta (TokenSale).
    mapping(uint256 => TokenSale) public tokensOnSale;

    // Lista que contiene los IDs de los NFTs que están actualmente en venta.
    uint256[] public listTokensOnSale;
    
    address public fundsCollector;
    address public feesCollector;

    bool public canBuy = true;
    bool public canClaim = true;
    bool public canTrade = true;

    uint256 public totalValue;
    uint256 public maxValueToRaise;

    uint16 public buyFee;
    uint16 public tradeFee;
    uint16 public maxBatchCount;
    uint32 public profitToPay;

    // Referencia al contrato ERC20 manejador de fondos. 
    IERC20 public fundsToken;

    constructor() ERC721("CCNFT", "CCNFT") {}

    // PUBLIC FUNCTIONS

    // Funcion de compra de NFTs. 
    function buy(uint256 value, uint256 amount) external nonReentrant {
        require(canBuy, "Buying is not enabled");
        require(amount > 0 && amount <= maxBatchCount, "Invalid amount");
        require(validValues[value], "Invalid NFT value");
        require(totalValue + (value * amount) <= maxValueToRaise, "Exceeds max value to raise");

        totalValue += value * amount;

        for (uint256 i = 0; i < amount; ++i) {
            uint256 tokenId = tokenIdTracker.current();
            values[tokenId] = value;
            _safeMint(msg.sender, tokenId);
            emit Buy(msg.sender, tokenId, value);
            tokenIdTracker.increment();
        }

        if (!fundsToken.transferFrom(msg.sender, fundsCollector, value * amount)) {
            revert("Cannot send funds tokens");
        }

        uint256 totalFee = (value * amount * buyFee) / 10000;
        if (!fundsToken.transferFrom(msg.sender, feesCollector, totalFee)) {
            revert("Cannot send fees tokens");
        }
    }

    // Funcion de "reclamo" de NFTs
    function claim(uint256[] calldata listTokenId) external nonReentrant {
        require(canClaim, "Claiming is not enabled");
        require(listTokenId.length > 0 && listTokenId.length <= maxBatchCount, "Invalid token list");
        uint256 claimValue = 0;
        
        for (uint256 i = 0; i < listTokenId.length; ++i) {
            uint256 tokenId = listTokenId[i];
            require(_exists(tokenId), "Token does not exist");
            require(ownerOf(tokenId) == msg.sender, "Only owner can claim");

            claimValue += values[tokenId];
            values[tokenId] = 0;

            TokenSale storage tokenSale = tokensOnSale[tokenId];
            tokenSale.onSale = false;
            tokenSale.price = 0;

            removeFromArray(tokenId);
            _burn(tokenId);
            emit Claim(msg.sender, tokenId);
        }

        totalValue -= claimValue;
        uint256 payout = claimValue + ((claimValue * profitToPay) / 10000);
        if (!fundsToken.transfer(msg.sender, payout)) {
            revert("cannot send funds");
        }
    }

    // Funcion de compra de NFT que esta en venta.
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
        removeFromArray(tokenId);
    }

        // Función para poner en venta un NFT.
    function putOnSale(uint256 tokenId, uint256 price) external {
        require(canTrade, "Trading is not enabled");
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        TokenSale storage tokenSale = tokensOnSale[tokenId];
        tokenSale.onSale = true;
        tokenSale.price = price;

        addToArray(tokenId);
        emit PutOnSale(tokenId, price);
    }

    // Función de retiro de venta de NFT.
    function removeFromSale(uint256 tokenId) external {
        require(canTrade, "Trading is not enabled");
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        TokenSale storage tokenSale = tokensOnSale[tokenId];
        require(tokenSale.onSale, "Token not on sale");
        tokenSale.onSale = false;
        tokenSale.price = 0;
        removeFromArray(tokenId);

        emit RemoveFromSale(tokenId);
    }

    // SETTERS

    // Utilización del token ERC20 para transacciones.
    function setFundsToken(address token) external onlyOwner { 
        require(token != address(0), "Funds token address cannot be zero");
        fundsToken = IERC20(token);
    }

    // Dirección para colectar los fondos de las ventas de NFTs.
    function setFundsCollector(address _address) external onlyOwner { 
        require(_address != address(0), "Funds collector address cannot be zero");
        fundsCollector = _address;
    }

    // Dirección para colectar las tarifas de transacción.
    function setFeesCollector(address _address) external onlyOwner { 
        require(_address != address(0), "Fees collector address cannot be zero");
        feesCollector = _address;
    }

    // Porcentaje de beneficio a pagar en las reclamaciones.
    function setProfitToPay(uint32 _profitToPay) external onlyOwner { 
        profitToPay = _profitToPay;
    }

    // Función que Habilita o deshabilita la compra de NFTs.
    function setCanBuy(bool _canBuy) external onlyOwner { 
        canBuy = _canBuy;
    }

    // Función que Habilita o deshabilita la reclamación de NFTs.
    function setCanClaim(bool _canClaim) external onlyOwner { 
        canClaim = _canClaim;
    }

    // Función que Habilita o deshabilita el intercambio de NFTs.
    function setCanTrade(bool _canTrade) external onlyOwner { 
        canTrade = _canTrade;
    }

    // Valor máximo que se puede recaudar de venta de NFTs.
    function setMaxValueToRaise(uint256 _maxValueToRaise) external onlyOwner { 
        maxValueToRaise = _maxValueToRaise;
    }
    
    // Función para agregar un valor válido para NFTs.   
    function addValidValues(uint256 value) external onlyOwner { 
        validValues[value] = true;
    }

    // Función para eliminar un valor válido previamente agregado.
    function deleteValidValues(uint256 value) external onlyOwner { 
        validValues[value] = false;
    }

    // Función para establecer la cantidad máxima de NFTs por operación.
    function setMaxBatchCount(uint16 _maxBatchCount) external onlyOwner { 
        maxBatchCount = _maxBatchCount;
    }

    // Tarifa aplicada a las compras de NFTs.
    function setBuyFee(uint16 _buyFee) external onlyOwner { 
        buyFee = _buyFee;
    }

    // Tarifa aplicada a las transacciones de NFTs.
    function setTradeFee(uint16 _tradeFee) external onlyOwner { 
        tradeFee = _tradeFee;
    }

    // GETTERS

    // IDs de los tokens que están disponibles para la venta.
    function getListTokensOnSale() public view returns (uint256[] memory) { 
        return listTokensOnSale;
    }

    // RECOVER FUNDS 

    // Retiro (propietario) de fondos en Ether almacenados en el contrato.
    function recover() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}(""); 
        if (!success) {
            revert("Failed to recover Ether");
        }
    }   

    // Retiro por parte del propietario de tokens ERC20.
    function recoverERC20(address token) external onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (!IERC20(token).transfer(owner(), amount)) {
            revert("Cannot send funds.");
        }
    }

    // RECEIVE

    // Permitir al contrato recibir Ether sin datos adicionales. 
    receive() external payable {}

    // ARRAYS

    // Verificar duplicados en el array antes de agregar un nuevo valor.
    function addToArray(uint256 tokenId) private {
        uint256 index = find(listTokensOnSale, tokenId);
        if (index == listTokensOnSale.length) {
            listTokensOnSale.push(tokenId);
        }
    }

    // Eliminar un valor del array.
    function removeFromArray(uint256 tokenId) private {
        uint256 index = find(listTokensOnSale, tokenId);
        if (index < listTokensOnSale.length) {
            listTokensOnSale[index] = listTokensOnSale[listTokensOnSale.length - 1];
            listTokensOnSale.pop();
        }
    }

    // Buscar un valor en un array y retornar su índice o la longitud del array si no se encuentra.
    function find(uint256[] storage list, uint256 value) private view returns(uint256) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == value) {
                return i;
            }
        }
        return list.length; // Si no se encuentra, retornar la longitud del array.
    }

    // NOT SUPPORTED FUNCTIONS

    // Funciones para deshabilitar las transferencias de NFTs,
    function transferFrom(address, address, uint256) 
        public 
        pure
        override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }

    function safeTransferFrom(address, address, uint256) 
        public pure override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) 
        public 
        pure
        override(ERC721, IERC721) 
    {
        revert("Not Allowed");
    }

    // Compliance required by Solidity

    // Funciones para asegurar que el contrato cumple con los estándares requeridos por ERC721 y ERC721Enumerable.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal 
        override(ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }    
}