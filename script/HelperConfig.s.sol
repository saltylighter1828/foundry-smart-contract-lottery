// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {
    VRFCoordinatorV2_5Mock
} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    /*VRF Mock Values - the V2_5 contract has these constructor variables*/
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    /// LINK / ETH price
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;

    address public constant FOUNDRY_DEFAULT_SENDER =
        0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        //calls the above function so code looks cleaner on DeployRaffle.s.sol
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether, //1e16
                interval: 30, //30 seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000, //500,000 gas
                subscriptionId: 99669601946357126231961837257790796077215090333875634036991691059739538495834,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0xa28De7725aEbE0A8f727BEcCdcd80C12ae12d984
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        //check to see if we set an active network config
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks and such
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UNIT_LINK
        );
        LinkToken linkToken = new LinkToken();

        // Create subscription on mock
        uint256 subId = vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.fundSubscription(subId, 100 ether);

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, //30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            // doesn't matter
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, //500,000 gas
            subscriptionId: subId,
            link: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER
        });
        return localNetworkConfig;
    }
}
