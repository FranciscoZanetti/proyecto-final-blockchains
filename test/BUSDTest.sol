// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BUSD.sol";

contract BUSDTest is Test {
    BUSD busd;

    function setUp() public {
        busd = new BUSD();
    }

    function testInitialSupply() public {
        assertEq(busd.totalSupply(), 10000000 * 10 ** 18);
    }

    function testNameAndSymbol() public {
        assertEq(busd.name(), "BUSD");
        assertEq(busd.symbol(), "BUSD");
    }
}
