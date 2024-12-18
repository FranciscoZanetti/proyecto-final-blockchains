// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BUSD.sol";

contract DeployBUSD is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_HEXA");

        vm.startBroadcast(deployerPrivateKey);

        BUSD busd = new BUSD();

        vm.stopBroadcast();

        console.log("BUSD deployed at:", address(busd));
    }
}
