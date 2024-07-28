// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../../script/Deploy-Lottery.s.sol";
import {Lottery} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    Lottery lottery;
    address public PLAYER = makeAddr("player");
    uint256 public STARTING_USER_BALANCE = 10 ether;
    address public player1 = makeAddr("player1");
    HelperConfig helperConfig;
    address vrfCoordinatorV2;
    uint256 entranceFee;
    bytes32 gas_lane;
    uint64 sub_id;
    uint32 callbackGasLimit;
    uint256 interval;
    uint256 deployerKey;

    function setUp() external {
        Deploy deployer = new Deploy();
        (lottery, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        vm.deal(player1, STARTING_USER_BALANCE);
        (
            vrfCoordinatorV2,
            entranceFee,
            gas_lane,
            sub_id,
            callbackGasLimit,
            interval,
            ,
deployerKey
        ) = helperConfig.activeNetworkConfig();
    }

    function testLotteryInitializesInOpenState() public view {
        assert(lottery.getLotteryState() == Lottery.lotteryState.OPEN);
    }

    function test_RevertWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Lottery.Raffle_notEnoughETHentered.selector);
        lottery.participateLottery();
    }

    function test_recordPlayerWhenEnter() public {
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        address playerAddress = lottery.getPlayers(0);
        assert(playerAddress == PLAYER);
    }

    function test_EmitAddressWhenEnterLottery() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit Lottery.lotteryEnter(PLAYER);
        lottery.participateLottery{value: entranceFee}();
    }

    function test_cannotEnterWhenLotteryIsCalculating() public {
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
        vm.expectRevert(Lottery.lottery_notOpen.selector);
        vm.prank(player1);

        lottery.participateLottery{value: entranceFee}();
    }

    function test_upKeepNotNeededWhenNotEnoughBalance() public {
        vm.prank(PLAYER);
        // lottery.participateLottery{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upKeepNeeded, ) = lottery.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    function test_upKeepNotNeededWhenLotteryStateIsCalculating() public {
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
        (bool upKeepNeeded, ) = lottery.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    function test_upKeepNotNeededWhenEnoughTimeHasNotPassed() public {
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        // vm.warp(block.timestamp + interval-10);
        // vm.roll(block.number + 1);
        (bool upKeepNeeded, ) = lottery.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    function test_UpKeepNeededWhenEverythingIsOk() public {
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upKeepNeeded, ) = lottery.checkUpkeep("");
        assert(upKeepNeeded == true);
    }

    function test_performUpKeepWillWorkOnlyIfCheckUpKeepIsTrue() public {
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
    }

    function test_performUpKeepWillRevertIfCheckUpKeepIsFalse() public {
        // vm.prank(PLAYER);
        // lottery.participateLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Lottery.lotteryState rState = lottery.getLotteryState();
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.lotteryUpKeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        lottery.performUpkeep("");
    }

    function test_performUpKeepUpdatesLotteryStateAndEmitRequestId() public {
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(lottery.getLotteryState() == Lottery.lotteryState.CALCULATING);
        assert(uint256(requestId) > 0);
    }
    modifier skipFork(){
        if(block.chainid != 31337)
        return;
        _;
    }
    function test_fulfillRandomWordsReverts(uint256 randomRequestId) public skipFork{
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function test_fulfillRandomWordsTestComplete() public skipFork{
        vm.prank(PLAYER);
        lottery.participateLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        uint256 additionalPlayer = 5;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i <= additionalPlayer; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            lottery.participateLottery{value: entranceFee}();
        }
        uint256 prize = entranceFee * (additionalPlayer + 1);
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(vrfCoordinatorV2).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );

        address winner = lottery.getRecentWinner();

        assert(winner != address(0));
        assert(lottery.getNumberOfPlayers() == 0);
        assert(lottery.getLotteryState() == Lottery.lotteryState.OPEN);
        assert(winner.balance == STARTING_USER_BALANCE + prize - entranceFee);
    }
}
