// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EmberLottery} from "../src/EmberLottery.sol";

contract EmberLotteryTest is Test {
    EmberLottery public lottery;

    address public owner = address(this);
    address public feeRecipient = makeAddr("feeRecipient");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant TICKET_PRICE = 0.01 ether;
    uint256 public constant DURATION = 1 days;

    event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice, uint256 endTime);
    event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketCount);
    event WinnerSelected(uint256 indexed lotteryId, address indexed winner, uint256 prize);
    event FeeSent(uint256 indexed lotteryId, address indexed feeRecipient, uint256 amount);

    function setUp() public {
        lottery = new EmberLottery(feeRecipient);

        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    // ============ Constructor Tests ============

    function test_constructor() public view {
        assertEq(lottery.owner(), owner);
        assertEq(lottery.feeRecipient(), feeRecipient);
        assertEq(lottery.currentLotteryId(), 0);
    }

    function test_constructor_revertZeroFeeRecipient() public {
        vm.expectRevert(EmberLottery.ZeroAddress.selector);
        new EmberLottery(address(0));
    }

    // ============ Start Lottery Tests ============

    function test_startLottery() public {
        vm.expectEmit(true, false, false, true);
        emit LotteryStarted(1, TICKET_PRICE, block.timestamp + DURATION);

        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        assertEq(lottery.currentLotteryId(), 1);
        assertTrue(lottery.isLotteryActive());

        (uint256 ticketPrice, uint256 endTime,,,, bool ended) = lottery.getLotteryInfo(1);
        assertEq(ticketPrice, TICKET_PRICE);
        assertEq(endTime, block.timestamp + DURATION);
        assertFalse(ended);
    }

    function test_startLottery_revertNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        lottery.startLottery(TICKET_PRICE, DURATION, 0);
    }

    function test_startLottery_revertZeroPrice() public {
        vm.expectRevert(EmberLottery.InvalidTicketPrice.selector);
        lottery.startLottery(0, DURATION, 0);
    }

    function test_startLottery_revertZeroDuration() public {
        vm.expectRevert(EmberLottery.InvalidDuration.selector);
        lottery.startLottery(TICKET_PRICE, 0, 0);
    }

    function test_startLottery_revertWhileActive() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.expectRevert(EmberLottery.LotteryAlreadyActive.selector);
        lottery.startLottery(TICKET_PRICE, DURATION, 0);
    }

    // ============ Buy Tickets Tests ============

    function test_buyTickets_single() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit TicketPurchased(1, alice, 1);
        lottery.buyTickets{value: TICKET_PRICE}(1);

        assertEq(lottery.getTicketCount(1, alice), 1);

        (,, uint256 totalPot, uint256 participantCount,,) = lottery.getLotteryInfo(1);
        assertEq(totalPot, TICKET_PRICE);
        assertEq(participantCount, 1);
    }

    function test_buyTickets_multiple() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.prank(alice);
        lottery.buyTickets{value: 5 * TICKET_PRICE}(5);

        assertEq(lottery.getTicketCount(1, alice), 5);

        address[] memory participants = lottery.getParticipants(1);
        assertEq(participants.length, 5);
        for (uint256 i = 0; i < 5; i++) {
            assertEq(participants[i], alice);
        }
    }

    function test_buyTickets_multipleUsers() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.prank(alice);
        lottery.buyTickets{value: 2 * TICKET_PRICE}(2);

        vm.prank(bob);
        lottery.buyTickets{value: 3 * TICKET_PRICE}(3);

        assertEq(lottery.getTicketCount(1, alice), 2);
        assertEq(lottery.getTicketCount(1, bob), 3);

        (,, uint256 totalPot, uint256 participantCount,,) = lottery.getLotteryInfo(1);
        assertEq(totalPot, 5 * TICKET_PRICE);
        assertEq(participantCount, 5);
    }

    function test_buyTickets_refundsExcess() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        uint256 balanceBefore = alice.balance;

        vm.prank(alice);
        lottery.buyTickets{value: 1 ether}(1); // Send way more than needed

        uint256 balanceAfter = alice.balance;
        assertEq(balanceBefore - balanceAfter, TICKET_PRICE);
    }

    function test_buyTickets_revertNotActive() public {
        vm.prank(alice);
        vm.expectRevert(EmberLottery.LotteryNotActive.selector);
        lottery.buyTickets{value: TICKET_PRICE}(1);
    }

    function test_buyTickets_revertAfterEnd() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(alice);
        vm.expectRevert(EmberLottery.LotteryNotActive.selector);
        lottery.buyTickets{value: TICKET_PRICE}(1);
    }

    function test_buyTickets_revertInsufficientPayment() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.prank(alice);
        vm.expectRevert(EmberLottery.InsufficientPayment.selector);
        lottery.buyTickets{value: TICKET_PRICE - 1}(1);
    }

    // ============ End Lottery Tests ============

    function test_endLottery_selectsWinner() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.prank(alice);
        lottery.buyTickets{value: TICKET_PRICE}(1);

        vm.prank(bob);
        lottery.buyTickets{value: TICKET_PRICE}(1);

        uint256 totalPot = 2 * TICKET_PRICE;
        uint256 expectedFee = (totalPot * 500) / 10000; // 5%
        uint256 expectedPrize = totalPot - expectedFee;

        uint256 feeRecipientBalanceBefore = feeRecipient.balance;

        vm.warp(block.timestamp + DURATION + 1);
        lottery.endLottery("");

        // Check fee was sent
        assertEq(feeRecipient.balance - feeRecipientBalanceBefore, expectedFee);

        // Check lottery ended
        (,,,, address winner, bool ended) = lottery.getLotteryInfo(1);
        assertTrue(ended);
        assertTrue(winner == alice || winner == bob);
    }

    function test_endLottery_noParticipants() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.warp(block.timestamp + DURATION + 1);

        vm.expectEmit(true, true, false, true);
        emit WinnerSelected(1, address(0), 0);
        lottery.endLottery("");

        (,,,, address winner, bool ended) = lottery.getLotteryInfo(1);
        assertTrue(ended);
        assertEq(winner, address(0));
    }

    function test_endLottery_revertNotEnded() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.expectRevert(EmberLottery.LotteryNotEnded.selector);
        lottery.endLottery("");
    }

    function test_endLottery_revertAlreadyEnded() public {
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        vm.prank(alice);
        lottery.buyTickets{value: TICKET_PRICE}(1);

        vm.warp(block.timestamp + DURATION + 1);
        lottery.endLottery("");

        vm.expectRevert(EmberLottery.LotteryNotActive.selector);
        lottery.endLottery("");
    }

    // ============ Admin Tests ============

    function test_setFeeRecipient() public {
        address newRecipient = makeAddr("newRecipient");
        lottery.setFeeRecipient(newRecipient);
        assertEq(lottery.feeRecipient(), newRecipient);
    }

    function test_setFeeRecipient_revertZeroAddress() public {
        vm.expectRevert(EmberLottery.ZeroAddress.selector);
        lottery.setFeeRecipient(address(0));
    }

    function test_setFeeRecipient_revertNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        lottery.setFeeRecipient(alice);
    }

    // ============ View Function Tests ============

    function test_isLotteryActive() public {
        assertFalse(lottery.isLotteryActive());

        lottery.startLottery(TICKET_PRICE, DURATION, 0);
        assertTrue(lottery.isLotteryActive());

        vm.warp(block.timestamp + DURATION + 1);
        assertFalse(lottery.isLotteryActive());
    }

    // ============ Fuzz Tests ============

    function testFuzz_buyTickets(uint256 ticketCount) public {
        vm.assume(ticketCount > 0 && ticketCount <= 100);

        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        uint256 cost = TICKET_PRICE * ticketCount;
        vm.deal(alice, cost);

        vm.prank(alice);
        lottery.buyTickets{value: cost}(ticketCount);

        assertEq(lottery.getTicketCount(1, alice), ticketCount);
    }

    function testFuzz_startLottery(uint256 ticketPrice, uint256 duration) public {
        vm.assume(ticketPrice > 0 && ticketPrice <= 100 ether);
        vm.assume(duration > 0 && duration <= 365 days);

        lottery.startLottery(ticketPrice, duration, 0);

        (uint256 storedPrice, uint256 endTime,,,,) = lottery.getLotteryInfo(1);
        assertEq(storedPrice, ticketPrice);
        assertEq(endTime, block.timestamp + duration);
    }

    // ============ Integration Test ============

    function test_fullLotteryFlow() public {
        // Start lottery
        lottery.startLottery(TICKET_PRICE, DURATION, 0);

        // Multiple users buy tickets
        vm.prank(alice);
        lottery.buyTickets{value: 3 * TICKET_PRICE}(3);

        vm.prank(bob);
        lottery.buyTickets{value: 2 * TICKET_PRICE}(2);

        vm.prank(charlie);
        lottery.buyTickets{value: 5 * TICKET_PRICE}(5);

        // Verify state
        (,, uint256 totalPot, uint256 participantCount,,) = lottery.getLotteryInfo(1);
        assertEq(totalPot, 10 * TICKET_PRICE);
        assertEq(participantCount, 10);

        // Time passes
        vm.warp(block.timestamp + DURATION + 1);

        // End lottery
        uint256 expectedFee = (totalPot * 500) / 10000;
        uint256 expectedPrize = totalPot - expectedFee;

        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;
        uint256 charlieBalBefore = charlie.balance;
        uint256 feeBalBefore = feeRecipient.balance;

        lottery.endLottery("");

        // Verify fee sent
        assertEq(feeRecipient.balance - feeBalBefore, expectedFee);

        // Verify winner got prize
        (,,,, address winner, bool ended) = lottery.getLotteryInfo(1);
        assertTrue(ended);

        uint256 aliceGain = alice.balance - aliceBalBefore;
        uint256 bobGain = bob.balance - bobBalBefore;
        uint256 charlieGain = charlie.balance - charlieBalBefore;

        // Exactly one person should have won
        uint256 totalGain = aliceGain + bobGain + charlieGain;
        assertEq(totalGain, expectedPrize);

        if (winner == alice) assertEq(aliceGain, expectedPrize);
        else if (winner == bob) assertEq(bobGain, expectedPrize);
        else if (winner == charlie) assertEq(charlieGain, expectedPrize);
    }
}
