import "forge-std/Script.sol";
import "../src/CCNFT.sol";

contract DeployCCNFT is Script {
    function run() external returns (CCNFT){
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_HEXA");

        vm.startBroadcast(deployerPrivateKey);

        CCNFT ccnft = new CCNFT();

        vm.stopBroadcast();

        console.log("CCNFT deployed at:", address(ccnft));
        return ccnft;
    }
}
