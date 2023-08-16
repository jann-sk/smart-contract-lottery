// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract TestRaffle is Test {
    event EnteredRaffle(address indexed player);
    Raffle raffle;
    HelperConfig helperCfg;

    uint fee;
    uint interval;
    address coordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint deployerKey;

    address public PLAYER = makeAddr("user1");
    uint public constant SEND_INITIAL_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperCfg) = deployer.run();
        vm.deal(PLAYER, SEND_INITIAL_BALANCE);

        (
            fee,
            interval,
            coordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,
            deployerKey
        ) = helperCfg.activeNetworkConfig();
    }

    /** Enter Raffle */
    function testInsufficientFeeforRaffle() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientENtranceFee.selector);
        raffle.enterRaffle();

        // check player added
        vm.prank(PLAYER);
        raffle.enterRaffle{value: fee}();
        address player1 = raffle.getPlayersByIndex(0);
        assertEq(player1, PLAYER);

        // check emit
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: fee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: fee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_EntryClosed.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: fee}();
    }

    function testCheckFalseForUpKeepNeeded() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: fee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testEnoughTimeNotPassed() public {
        // vm.prank(PLAYER);
        // raffle.enterRaffle{value: fee}();

        uint balance = 0;
        uint noOfPLayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        // vm.warp(block.timestamp - interval / 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__CannotPickWinner.selector,
                balance,
                noOfPLayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    function testIfRequestIdIsEmitted() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: fee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint(raffleState) == 1);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: fee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep()
        public
        raffleEntered
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(
            0,
            address(raffle)
        );

        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(
            1,
            address(raffle)
        );
    }

    function _testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
        skipFork
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 2 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: fee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(coordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = fee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
