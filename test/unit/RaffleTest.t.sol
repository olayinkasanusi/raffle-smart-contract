// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import { Raffle } from "../../src/Raffle.sol";
import { Test, console } from "forge-std/Test.sol";
import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { Vm } from "forge-std/Vm.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    /**
     * EVENTS
     */
    event RaffleEntered(address indexed player);
    // event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: entranceFee }();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleInitializesInOpenState() public view {
        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenNotEnoughETHIsSent() public {
        // Arrange
        vm.prank(PLAYER);
        // vm.deal(PLAYER, STARTING_USER_BALANCE);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETH.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        raffle.enterRaffle{ value: entranceFee }();

        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{ value: entranceFee }();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public raffleEntered {
        // 2. Act - Transition state to CALCULATING
        raffle.performUpkeep(""); // This changes state to RaffleState.CALCULATING

        // 3. Assert - Now try to enter while it is calculating
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: entranceFee }();
    }

    function testCheckUpkeepIfThereIsNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public raffleEntered {
        // Arrange

        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{ value: entranceFee }();

        // Act
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testConstructorSetsVariablesCorrectly() public {
        // Arrange
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Assert
        assert(raffle.getEntranceFee() == config.entranceFee);
        assert(raffle.getInterval() == config.interval);
        assert(raffle.getVrfCoordinator() == config.vrfCoordinator);
        assert(raffle.getGasLane() == config.gasLane);
        assert(raffle.getCallbackGasLimit() == config.callbackGasLimit);
        assert(raffle.getSubscriptionId() == config.subscriptionId);
    }

    function testPerformUpkeepOnlyRunsIfCheckUpkeepIsTrue() public raffleEntered {
        // Arrange

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 currentPlayers = 0;
        uint256 currentState = uint256(Raffle.RaffleState.OPEN);

        vm.prank(PLAYER);
        raffle.enterRaffle{ value: entranceFee }();
        currentBalance += entranceFee;
        currentPlayers += 1;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepIsFalse.selector, currentBalance, currentPlayers, currentState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        assert(requestId != bytes32(0));
    }

    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId) public raffleEntered {
        // Arrange

        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsTheLotteryAndSendsMoney() public raffleEntered {
        // Arrange
        uint256 additionalEntrants = 10;
        uint256 startingIndex = 10; // We already have 1 entrant from the raffleEntered modifier

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = makeAddr(string(abi.encodePacked("player", uint256(i))));
            hoax(newPlayer, STARTING_USER_BALANCE);
            raffle.enterRaffle{ value: entranceFee }();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        //
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 totalPrize = entranceFee * (additionalEntrants + 1);
        address recentWinner = raffle.getRecentWinner();

        //
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(recentWinner != address(0));
        assert(raffle.getNumberOfPlayers() == 0);
        assert(recentWinner.balance == (STARTING_USER_BALANCE + totalPrize - entranceFee));
        assert(endingTimeStamp > startingTimeStamp);
    }
}
