// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BUSD.sol";
import "../src/CCNFT.sol";
import "forge-std/Vm.sol";

contract CCNFTTest is Test {
    address deployer = address(this);
    address c1 = address(0x1);
    address c2 = address(0x2);
    address funds = address(0x3);
    address fees = address(0x4);
    BUSD busd;
    CCNFT ccnft;

    function setUp() public {
        busd = new BUSD();

        ccnft = new CCNFT();
        ccnft.setFundsToken(address(busd));
        ccnft.setFundsCollector(funds);
        ccnft.setFeesCollector(fees);
        ccnft.setMaxValueToRaise(100 ether);
        ccnft.setBuyFee(100); // 1% fee
        ccnft.setTradeFee(50); // 0.5% fee
        ccnft.setMaxBatchCount(10);
        ccnft.setProfitToPay(500); // 5% profit
        ccnft.addValidValues(0.001 ether);

        deal(address(busd), c1, 1 ether);
    }

    function testSetFundsCollector() public {
        ccnft.setFundsCollector(c1);
        assertEq(ccnft.fundsCollector(), c1);
    }

    function testSetFeesCollector() public {
        ccnft.setFeesCollector(c1);
        assertEq(ccnft.feesCollector(), c1);
    }

    function testSetProfitToPay() public {
        ccnft.setProfitToPay(1000); // 10% profit
        assertEq(ccnft.profitToPay(), 1000);
    }

    function testSetCanBuy() public {
        ccnft.setCanBuy(true);
        assertTrue(ccnft.canBuy());
        ccnft.setCanBuy(false);
        assertFalse(ccnft.canBuy());
    }

    function testSetCanTrade() public {
        ccnft.setCanTrade(true);
        assertTrue(ccnft.canTrade());
        ccnft.setCanTrade(false);
        assertFalse(ccnft.canTrade());
    }

    function testSetCanClaim() public {
        ccnft.setCanClaim(true);
        assertTrue(ccnft.canClaim());
        ccnft.setCanClaim(false);
        assertFalse(ccnft.canClaim());
    }

    function testSetMaxValueToRaise() public {
        ccnft.setMaxValueToRaise(2000 ether);
        assertEq(ccnft.maxValueToRaise(), 2000 ether);
        ccnft.setMaxValueToRaise(1000 ether);
        assertEq(ccnft.maxValueToRaise(), 1000 ether);
    }

    function testAddValidValues() public {
        ccnft.addValidValues(0.1 ether);
        assertTrue(ccnft.validValues(0.1 ether));
    }

    function testDeleteValidValues() public {
        ccnft.addValidValues(0.1 ether);
        assertTrue(ccnft.validValues(0.1 ether));
        ccnft.deleteValidValues(0.1 ether);
        assertFalse(ccnft.validValues(0.1 ether));
    }

    function testSetMaxBatchCount() public {
        ccnft.setMaxBatchCount(20);
        assertEq(ccnft.maxBatchCount(), 20);
    }

    function testSetBuyFee() public {
        ccnft.setBuyFee(200); // 2% fee
        assertEq(ccnft.buyFee(), 200);
    }

    function testSetTradeFee() public {
        ccnft.setTradeFee(100); // 1% fee
        assertEq(ccnft.tradeFee(), 100);
    }

    function testCannotTradeWhenCanTradeIsFalse() public {
        vm.prank(c1);
        busd.approve(address(ccnft), 1 ether);
        ccnft.setCanTrade(false);
        uint256 tokenId = 0;
        vm.expectRevert("Trading is not enabled");
        ccnft.trade(tokenId);
    }

    function testCannotTradeWhenTokenDoesNotExist() public {
        ccnft.setCanTrade(true);
        uint256 nonExistentTokenId = 999;
        vm.expectRevert("Token does not exist");
        ccnft.trade(nonExistentTokenId);
    }
}
