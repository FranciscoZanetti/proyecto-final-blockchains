// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CCNFT.sol";

contract Buy is Script {
    function run() external {
        address CCNFT_address = 0x63Af39c518254474285D1238561059065F280838;

        uint256 value = 0.01 ether;
        uint256 amount = 1;

        CCNFT nft = CCNFT(payable(CCNFT_address));
        nft.buy(value, amount);
    }
}
