// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/CCNFT.sol";

contract CCNFTTest is Test {
    CCNFT ccnft;

    function setUp() public {
        ccnft = new CCNFT();
    }

    function testConstructorInitialization() public {
        assertEq(ccnft.buyFee(), 500);
        assertEq(ccnft.tradeFee(), 300);
        assertEq(ccnft.maxBatchCount(), 20);
        assertEq(ccnft.profitToPay(), 1000);
        assertEq(ccnft.maxValueToRaise(), 1000 ether);
    }

    function testSetFundsCollector() public {
        address funds = address(0x123);
        ccnft.setFundsCollector(funds);
        assertEq(ccnft.getFundsCollector(), funds);
    }

    function testSetFeesCollector() public {
        address fees = address(0x456);
        ccnft.setFeesCollector(fees);
        assertEq(ccnft.getFeesCollector(), fees);
    }

    function testSetCanBuy() public {
        ccnft.setCanBuy(true);
        assertEq(ccnft.canBuy(), true);
        ccnft.setCanBuy(false);
        assertEq(ccnft.canBuy(), false);
    }

    function testSetMaxValueToRaise() public {
        uint256 maxValue = 100 ether;
        ccnft.setMaxValueToRaise(maxValue);
        assertEq(ccnft.getMaxValueToRaise(), maxValue);
    }

    function testBuyNFT() public {
        // Aprobar tokens BUSD para el contrato
        busd.approve(address(ccnft), 1 ether);

        // Comprar un NFT
        ccnft.buy(1 ether, 1);

        // Verificar que el usuario tiene el NFT
        assertEq(ccnft.balanceOf(address(this)), 1);
    }

    function testPutOnSaleAndTrade() public {
        // El propietario pone el NFT en venta
        ccnft.putOnSale(1, 2 ether);

        // Verificar que el NFT está en venta
        (bool onSale, uint256 price) = ccnft.tokensOnSale(1);
        assertTrue(onSale);
        assertEq(price, 2 ether);

        // Otro usuario compra el NFT
        vm.prank(address(0x123));
        ccnft.trade{value: 2 ether}(1);

        // Verificar la nueva propiedad
        assertEq(ccnft.ownerOf(1), address(0x123));
    }

    function testMaxValueToRaise() public {
        uint256 currentValue = ccnft.totalRaised();
        ccnft.setMaxValueToRaise(currentValue + 1 ether);
        assertEq(ccnft.getMaxValueToRaise(), currentValue + 1 ether);
    }

}
