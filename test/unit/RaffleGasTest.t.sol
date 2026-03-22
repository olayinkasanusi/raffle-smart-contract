// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { Raffle } from "../../src/Raffle.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Vm } from "forge-std/Vm.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleGasTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    VRFCoordinatorV2_5Mock vrfCoordinator;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vrfCoordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testFulfillRandomWordsGasUsage() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: 0.01 ether }();
        vm.warp(block.timestamp + 31);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 gasStart = gasleft();
        vrfCoordinator.fulfillRandomWords(uint256(requestId), address(raffle));
        uint256 gasUsed = gasStart - gasleft();

        console.log("FulfillRandomWords Actual Usage:", gasUsed);
    }
}
