// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkCfg {
        uint fee;
        uint interval;
        address coordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint deployerKey;
    }

    NetworkCfg public activeNetworkConfig;
    uint public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getorCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkCfg memory) {
        return
            NetworkCfg({
                fee: 0.0002 ether,
                interval: 30,
                coordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0,
                callbackGasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getorCreateAnvilEthConfig() public returns (NetworkCfg memory) {
        if (activeNetworkConfig.coordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 BASE_FEE = 0.002 ether;
        uint96 GAS_PRICE_LINK = 0.01 ether;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrf = new VRFCoordinatorV2Mock(
            BASE_FEE,
            GAS_PRICE_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkCfg({
                fee: 0.0002 ether,
                interval: 30,
                coordinator: address(vrf),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0,
                callbackGasLimit: 500000,
                link: address(linkToken),
                deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
            });
    }

    function getActiveNetworkCfg() public view returns (NetworkCfg memory) {
        return activeNetworkConfig;
    }
}
