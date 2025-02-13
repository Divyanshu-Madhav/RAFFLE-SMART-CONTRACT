// SPDX-License-Identifier:MIT
pragma solidity ^0.8.13;
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address vrfCoordinatorV2;
        uint256 entranceFee;
        bytes32 gas_lane;
        uint64 sub_id;
        uint32 callbackGasLimit;
        uint256 interval;
        address link;
        uint256 deployerKey;
    }
    NetworkConfig public activeNetworkConfig;
    uint256 public constant ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111)
            activeNetworkConfig = getSepoliaEthConfig();
        else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                vrfCoordinatorV2: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                entranceFee: 0.01 ether,
                gas_lane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                sub_id: 10069,
                callbackGasLimit: 500000,
                interval: 30,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinatorV2 != address(0))
            return activeNetworkConfig;
        uint96 BASE_FEE = 0.25 ether;
        uint96 GAS_PRICE_LINK = 1e9;
        vm.startBroadcast();

        VRFCoordinatorV2Mock vrfaddress = new VRFCoordinatorV2Mock(
            BASE_FEE,
            GAS_PRICE_LINK
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();
        return
            NetworkConfig({
                vrfCoordinatorV2: address(vrfaddress),
                entranceFee: 0.01 ether,
                gas_lane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                sub_id: 0,
                callbackGasLimit: 500000,
                interval: 30,
                link: address(link),
                deployerKey: ANVIL_PRIVATE_KEY
            });
    }
}
