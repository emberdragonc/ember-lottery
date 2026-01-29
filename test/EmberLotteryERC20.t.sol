// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EmberLotteryERC20} from "../src/EmberLotteryERC20.sol";

// Mock ERC20 for testing
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract EmberLotteryERC20Test is Test {
    EmberLotteryERC20 public lottery;
    MockERC20 public token;

    address public owner = address(this);
    address public feeRecipient = makeAddr("feeRecipient");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 public constant TICKET_PRICE = 100e18; // 100 tokens
    uint256 public constant DURATION = 1 days;

    event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice, uint256 endTime);
    event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketCount, uint256 totalCost);
    event WinnerSelected(uint256 indexed lotteryId, address indexed winner, uint256 prize);
    event FeeSent(uint256 indexed lotteryId, address indexed feeRecipient, uint256 amount);

    function setUp() public {
        token = new MockERC20();
        lottery = new EmberLotteryERC20(address(token), feeRecipient);

        // Mint tokens to test accounts
        token.mint(alice, 10000e18);
        token.mint(bob, 10000e18);
        token.mint(charlie, 10000e18);
    }

    // ============ Constructor Tests ============

    function test_constructor() public view {
        assertEq(lottery.owner(), owner);
        assertEq(lottery.feeRecipient(), feeRecipient);
        assertEq(lottery.token(), address(token));
        assertEq(lottery.currentLotteryId(), 0);
    }

    function test_constructor_revertZeroToken() public {
        vm.expectRevert(EmberLotteryERC20.ZeroAddress.selector);
        new EmberLotteryERC20(address(0), feeRecipient);
    }

    function test_constructor_revertZeroFeeRecipient() public {
        vm.expectRevert(EmberLotteryERC20.ZeroAddress.selector);
        new EmberLotteryERC20(address(token), address(0));
    }

    // ============ Start Lottery Tests ============

    function test_startLottery() public {
        vm.expectEmit(true, false, false, true);
        emit LotteryStarted(1, TICKET_PRICE, block.timestamp + DURATION);

        lottery.startLottery(TICKET_PRICE, DURATION);

        assertEq(lottery.currentLotteryId(), 1);
        assertTrue(lottery.isLotteryActive());

        (uint256 ticketPrice, uint256 endTime,,,, bool ended) = lottery.getLotteryInfo(1);
        assertEq(ticketPrice, TICKET_PRICE);
        assertEq(endTime, block.timestamp + DURATION);
        assertFalse(ended);
    }

    // ============ Buy Tickets Tests ============

    function test_buyTickets_exactApproval() public {
        lottery.startLottery(TICKET_PRICE, DURATION);

        uint256 cost = lottery.getTicketCost(1);
        assertEq(cost, TICKET_PRICE);

        // Approve EXACT amount (not infinite)
        vm.startPrank(alice);
        token.approve(address(lottery), cost);

        // Verify allowance is exact
        assertEq(token.allowance(alice, address(lottery)), cost);

        lottery.buyTickets(1);
        vm.stopPrank();

        assertEq(lottery.getTicketCount(1, alice), 1);

        // Allowance should be 0 after (spent exactly)
        assertEq(token.allowance(alice, address(lottery)), 0);
    }

    function test_buyTickets_multipleTickets() public {
        lottery.startLottery(TICKET_PRICE, DURATION);

        uint256 ticketsToBuy = 5;
        uint256 exactCost = lottery.getTicketCost(ticketsToBuy);
        assertEq(exactCost, TICKET_PRICE * ticketsToBuy);

        vm.startPrank(alice);
        token.approve(address(lottery), exactCost);
        lottery.buyTickets(ticketsToBuy);
        vm.stopPrank();

        assertEq(lottery.getTicketCount(1, alice), ticketsToBuy);

        address[] memory participants = lottery.getParticipants(1);
        assertEq(participants.length, ticketsToBuy);
    }

    function test_buyTickets_multipleUsers() public {
        lottery.startLottery(TICKET_PRICE, DURATION);

        // Alice buys 2
        vm.startPrank(alice);
        token.approve(address(lottery), lottery.getTicketCost(2));
        lottery.buyTickets(2);
        vm.stopPrank();

        // Bob buys 3
        vm.startPrank(bob);
        token.approve(address(lottery), lottery.getTicketCost(3));
        lottery.buyTickets(3);
        vm.stopPrank();

        assertEq(lottery.getTicketCount(1, alice), 2);
        assertEq(lottery.getTicketCount(1, bob), 3);

        (,, uint256 totalPot, uint256 participantCount,,) = lottery.getLotteryInfo(1);
        assertEq(totalPot, 5 * TICKET_PRICE);
        assertEq(participantCount, 5);
    }

    function test_buyTickets_revertZeroAmount() public {
        lottery.startLottery(TICKET_PRICE, DURATION);

        vm.prank(alice);
        vm.expectRevert(EmberLotteryERC20.ZeroAmount.selector);
        lottery.buyTickets(0);
    }

    function test_buyTickets_revertNotActive() public {
        vm.prank(alice);
        vm.expectRevert(EmberLotteryERC20.LotteryNotActive.selector);
        lottery.buyTickets(1);
    }

    // ============ End Lottery Tests ============

    function test_endLottery_selectsWinner() public {
        lottery.startLottery(TICKET_PRICE, DURATION);

        vm.startPrank(alice);
        token.approve(address(lottery), TICKET_PRICE);
        lottery.buyTickets(1);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(lottery), TICKET_PRICE);
        lottery.buyTickets(1);
        vm.stopPrank();

        uint256 totalPot = 2 * TICKET_PRICE;
        uint256 expectedFee = (totalPot * 500) / 10000; // 5%
        uint256 expectedPrize = totalPot - expectedFee;

        uint256 feeRecipientBalanceBefore = token.balanceOf(feeRecipient);

        vm.warp(block.timestamp + DURATION + 1);
        lottery.endLottery();

        // Check fee was sent
        assertEq(token.balanceOf(feeRecipient) - feeRecipientBalanceBefore, expectedFee);

        // Check lottery ended
        (,,,, address winner, bool ended) = lottery.getLotteryInfo(1);
        assertTrue(ended);
        assertTrue(winner == alice || winner == bob);
    }

    // ============ Get Ticket Cost Tests ============

    function test_getTicketCost() public {
        lottery.startLottery(TICKET_PRICE, DURATION);

        assertEq(lottery.getTicketCost(1), TICKET_PRICE);
        assertEq(lottery.getTicketCost(5), TICKET_PRICE * 5);
        assertEq(lottery.getTicketCost(100), TICKET_PRICE * 100);
    }

    // ============ Integration Test ============

    function test_fullLotteryFlow_withExactApprovals() public {
        // Start lottery
        lottery.startLottery(TICKET_PRICE, DURATION);

        // Alice buys 3 tickets with EXACT approval
        uint256 aliceCost = lottery.getTicketCost(3);
        vm.startPrank(alice);
        token.approve(address(lottery), aliceCost);
        lottery.buyTickets(3);
        vm.stopPrank();

        // Bob buys 2 tickets with EXACT approval
        uint256 bobCost = lottery.getTicketCost(2);
        vm.startPrank(bob);
        token.approve(address(lottery), bobCost);
        lottery.buyTickets(2);
        vm.stopPrank();

        // Charlie buys 5 tickets with EXACT approval
        uint256 charlieCost = lottery.getTicketCost(5);
        vm.startPrank(charlie);
        token.approve(address(lottery), charlieCost);
        lottery.buyTickets(5);
        vm.stopPrank();

        // Verify state
        (,, uint256 totalPot, uint256 participantCount,,) = lottery.getLotteryInfo(1);
        assertEq(totalPot, 10 * TICKET_PRICE);
        assertEq(participantCount, 10);

        // Verify all allowances are 0 (exact approvals consumed)
        assertEq(token.allowance(alice, address(lottery)), 0);
        assertEq(token.allowance(bob, address(lottery)), 0);
        assertEq(token.allowance(charlie, address(lottery)), 0);

        // Time passes
        vm.warp(block.timestamp + DURATION + 1);

        // End lottery
        uint256 expectedFee = (totalPot * 500) / 10000;
        uint256 expectedPrize = totalPot - expectedFee;

        uint256 aliceBalBefore = token.balanceOf(alice);
        uint256 bobBalBefore = token.balanceOf(bob);
        uint256 charlieBalBefore = token.balanceOf(charlie);
        uint256 feeBalBefore = token.balanceOf(feeRecipient);

        lottery.endLottery();

        // Verify fee sent
        assertEq(token.balanceOf(feeRecipient) - feeBalBefore, expectedFee);

        // Verify winner got prize
        (,,,, address winner, bool ended) = lottery.getLotteryInfo(1);
        assertTrue(ended);

        uint256 aliceGain = token.balanceOf(alice) - aliceBalBefore;
        uint256 bobGain = token.balanceOf(bob) - bobBalBefore;
        uint256 charlieGain = token.balanceOf(charlie) - charlieBalBefore;

        // Exactly one person should have won
        uint256 totalGain = aliceGain + bobGain + charlieGain;
        assertEq(totalGain, expectedPrize);
    }

    // ============ Fuzz Tests ============

    function testFuzz_exactApprovalAmount(uint256 ticketCount) public {
        vm.assume(ticketCount > 0 && ticketCount <= 100);

        lottery.startLottery(TICKET_PRICE, DURATION);

        uint256 exactCost = lottery.getTicketCost(ticketCount);
        assertEq(exactCost, TICKET_PRICE * ticketCount);

        vm.startPrank(alice);
        token.approve(address(lottery), exactCost);
        lottery.buyTickets(ticketCount);
        vm.stopPrank();

        assertEq(lottery.getTicketCount(1, alice), ticketCount);
        assertEq(token.allowance(alice, address(lottery)), 0); // Exact approval consumed
    }
}
