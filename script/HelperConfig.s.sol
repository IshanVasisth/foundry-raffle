//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Raffle} from "../src/Raffle.sol";
import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant SEPOLIA_CHAINID = 11155111;
    uint256 public constant ANVIL_CHAINID = 31337;
}

contract HelperConfig is Script, CodeConstants {
    //VRF Mock values
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    constructor() {
        if (block.chainid == CodeConstants.SEPOLIA_CHAINID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == CodeConstants.ANVIL_CHAINID) {
            activeNetworkConfig = getorCreateAnvilEthConfig();
        } else {
            revert("Network not supported");
        }
    }

    struct NetworkConfig {
        uint256 subscriptionId;
        address vrfCoordinator;
        uint256 entranceFee;
        uint256 interval;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        address linkToken;
        address account;
    }
    NetworkConfig public activeNetworkConfig;

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                subscriptionId: 41711742633957806741640324333705738622539321914990972734479880328805808813722,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                entranceFee: 0.01 ether,
                interval: 30,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0x46E668f64795AeE081c6270279c11A1Ba7b3d6cf
            });
    }

    function getorCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        //check if we have already set active network config
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        //if not, deploy a mock VRF Coordinator and return its address

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );
        address linkTokenAddress = address(new LinkToken());
        vm.stopBroadcast();

        return
            NetworkConfig({
                subscriptionId: 0,
                vrfCoordinator: address(vrfCoordinatorMock),
                entranceFee: 0.01 ether,
                interval: 30,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                linkToken: linkTokenAddress,
                account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
            });
    }

    function getActiveNetworkConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }

    function setSubscriptionId(uint256 subId) public { 
        activeNetworkConfig.subscriptionId = subId;
    }
}
