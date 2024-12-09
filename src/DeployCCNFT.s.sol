// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CCNFT.sol";
import "../src/BUSD.sol";

contract DeployCCNFT is Script {
    function run() external {
        vm.startBroadcast();

        // Dirección del token BUSD (debe estar previamente desplegado)
        address busdToken = 0x1234567890123456789012345678901234567890; // Cambiar por la dirección real

        // Parámetros del constructor
        string memory name = "CCNFT";
        string memory symbol = "CCN";
        address fundsCollector = 0x1111111111111111111111111111111111111111; // Cambiar por dirección real
        address feesCollector = 0x2222222222222222222222222222222222222222; // Cambiar por dirección real
        uint16 buyFee = 500; // 5%
        uint16 tradeFee = 300; // 3%
        uint256 maxBatchCount = 20;
        uint16 profitToPay = 1000; // 10%
        uint256 maxValueToRaise = 1000 ether;

        // Desplegar CCNFT
        CCNFT ccnft = new CCNFT(
            name,
            symbol,
            busdToken,
            fundsCollector,
            feesCollector,
            buyFee,
            tradeFee,
            maxBatchCount,
            profitToPay,
            maxValueToRaise
        );

        console.log("CCNFT deployed at:", address(ccnft));
        vm.stopBroadcast();
    }
}
