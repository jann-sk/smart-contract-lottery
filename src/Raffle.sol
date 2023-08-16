// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title Smart contract lottery
 * @author Janani
 * @notice Create sample Raffle
 * @dev Implemented Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__InsufficientENtranceFee();
    error Raffle__NotATimeToPickWinner();
    error Raffle_TransferToWinnerFailed();
    error Raffle_EntryClosed();
    error Raffle__CannotPickWinner(
        uint balance,
        uint noOfPLayers,
        uint raffleState
    );

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant NUM_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint private immutable i_entranceFee;
    uint private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_coordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    address payable private s_recentWinner;
    uint private s_lastTimeStamp;
    RaffleState s_rState;

    /* Events */
    event RequestedRaffleWinner(uint256 indexed requestId);
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(
        uint _fee,
        uint _interval,
        address _coordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_coordinator) {
        i_entranceFee = _fee;
        s_lastTimeStamp = block.timestamp;
        i_interval = _interval;
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
        i_coordinator = VRFCoordinatorV2Interface(_coordinator);
        s_rState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__InsufficientENtranceFee();
        }

        if (s_rState != RaffleState.OPEN) {
            revert Raffle_EntryClosed();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /*_requestId */,
        uint256[] memory _randomWords
    ) internal override {
        uint index = _randomWords[0] % s_players.length;
        address payable winner = s_players[index];
        s_recentWinner = winner;
        s_rState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferToWinnerFailed();
        }
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool isOpen = RaffleState.OPEN == s_rState;
        upkeepNeeded = (hasTimePassed && hasBalance && hasPlayers && isOpen);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upKeepNeeded, ) = checkUpkeep("");

        if (!upKeepNeeded) {
            revert Raffle__CannotPickWinner(
                address(this).balance,
                s_players.length,
                uint(s_rState)
            );
        }

        s_rState = RaffleState.CALCULATING;

        uint requestID = VRFCoordinatorV2Interface(i_coordinator)
            .requestRandomWords(
                i_gasLane,
                i_subscriptionId,
                NUM_CONFIRMATIONS,
                i_callbackGasLimit,
                NUM_WORDS
            );

        emit RequestedRaffleWinner(requestID);
    }

    /** Getter functions */

    function getEntranceFee() public view returns (uint) {
        return i_entranceFee;
    }

    function getPlayersByIndex(uint index) public view returns (address) {
        return s_players[index];
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_rState;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }
}
