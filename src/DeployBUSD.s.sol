// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BUSD.sol";

contract DeployBUSD is Script {
    function run() external {
        vm.startBroadcast();
        BUSD busd = new BUSD();
        console.log("BUSD deployed at:", address(busd));
        vm.stopBroadcast();
    }
}
