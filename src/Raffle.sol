// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {console} from "forge-std/console.sol";

contract Lottery is VRFConsumerBaseV2, AutomationCompatibleInterface {
    error Raffle_notEnoughETHentered();
error lottery_transaction_failed();
error lottery_notOpen();
error lotteryUpKeepNotNeeded(uint256 cuurentBalance, uint256 numPlayers, uint256 lotteryState);

    enum lotteryState {
        OPEN,
        CALCULATING
    }

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_VRFcoordinatorV2;
    bytes32 private immutable i_gas_lane;
    uint64 private immutable i_sub_id;
    uint16 private constant minimumRequestConfirmations = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant numWords = 1;
    address payable s_recentWinner;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    lotteryState private s_lotteryState;

    event lotteryEnter(address indexed player);
    event winnerPicked(address indexed winner);
    event requestedLotteryWinner(uint256 indexed requestId);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gas_lane,
        uint64 sub_id,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_VRFcoordinatorV2 = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gas_lane = gas_lane;
        i_sub_id = sub_id;
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = lotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function participateLottery() public payable {
        if (msg.value < i_entranceFee) revert Raffle_notEnoughETHentered();
        if (s_lotteryState != lotteryState.OPEN) revert lottery_notOpen();
        s_players.push(payable(msg.sender));

        emit lotteryEnter(msg.sender);
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view override returns (bool upKeepNeeded, bytes memory /*performData*/) {
        bool isOpen = (s_lotteryState == lotteryState.OPEN);
        bool timePassed = (block.timestamp - s_lastTimeStamp > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upKeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upKeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            console.log(address(this));
            revert lotteryUpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_lotteryState)
            );
        }
        s_lotteryState = lotteryState.CALCULATING;
        uint256 requestId = i_VRFcoordinatorV2.requestRandomWords(
            i_gas_lane,
            i_sub_id,
            minimumRequestConfirmations,
            i_callbackGasLimit,
            numWords
        );
        emit requestedLotteryWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert lottery_transaction_failed();
        }
        emit winnerPicked(recentWinner);
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = lotteryState.OPEN;
        
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLotteryState() public view returns (lotteryState) {
        return s_lotteryState;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
