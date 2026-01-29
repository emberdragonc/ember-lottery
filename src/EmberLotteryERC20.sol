// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title EmberLotteryERC20
 * @author Ember 🐉
 * @notice ERC20 lottery where users buy tickets with tokens, winner takes pot minus fee
 * @dev EIP-7702 Compatible - uses msg.sender only, no tx.origin checks
 * @dev Supports EXACT approval amounts - users can approve precisely the ticket cost
 */
contract EmberLotteryERC20 is Ownable, ReentrancyGuard {
    // ============ Errors ============
    error LotteryNotActive();
    error LotteryNotEnded();
    error LotteryAlreadyActive();
    error InvalidTicketPrice();
    error InvalidDuration();
    error NoParticipants();
    error InsufficientAllowance();
    error TransferFailed();
    error ZeroAddress();
    error ZeroAmount();

    // ============ Events ============
    event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice, uint256 endTime);
    event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketCount, uint256 totalCost);
    event WinnerSelected(uint256 indexed lotteryId, address indexed winner, uint256 prize);
    event FeeSent(uint256 indexed lotteryId, address indexed feeRecipient, uint256 amount);

    // ============ Structs ============
    struct Lottery {
        uint256 ticketPrice;
        uint256 endTime;
        uint256 totalPot;
        address[] participants;
        address winner;
        bool ended;
    }

    // ============ Constants ============
    uint256 public constant FEE_BPS = 500; // 5% fee
    uint256 public constant MAX_BPS = 10000;

    // ============ Immutables ============
    address public immutable token;

    // ============ State ============
    uint256 public currentLotteryId;
    address public feeRecipient;

    mapping(uint256 => Lottery) public lotteries;
    mapping(uint256 => mapping(address => uint256)) public ticketCount;

    // ============ Constructor ============
    constructor(address _token, address _feeRecipient) {
        if (_token == address(0)) revert ZeroAddress();
        if (_feeRecipient == address(0)) revert ZeroAddress();
        _initializeOwner(msg.sender);
        token = _token;
        feeRecipient = _feeRecipient;
    }

    // ============ External Functions ============

    /**
     * @notice Start a new lottery
     * @param _ticketPrice Price per ticket in token units
     * @param _duration Duration in seconds
     */
    function startLottery(uint256 _ticketPrice, uint256 _duration) external onlyOwner {
        if (_ticketPrice == 0) revert InvalidTicketPrice();
        if (_duration == 0) revert InvalidDuration();

        // Check previous lottery is ended
        if (currentLotteryId > 0) {
            Lottery storage prev = lotteries[currentLotteryId];
            if (!prev.ended && block.timestamp < prev.endTime) revert LotteryAlreadyActive();
        }

        currentLotteryId++;

        Lottery storage lottery = lotteries[currentLotteryId];
        lottery.ticketPrice = _ticketPrice;
        lottery.endTime = block.timestamp + _duration;

        emit LotteryStarted(currentLotteryId, _ticketPrice, lottery.endTime);
    }

    /**
     * @notice Buy tickets for the current lottery
     * @param _ticketCount Number of tickets to buy
     * @dev Requires prior approval of EXACT amount (ticketPrice * ticketCount)
     * @dev With EIP-7702, approval + buyTickets can be batched in a single tx
     */
    function buyTickets(uint256 _ticketCount) external nonReentrant {
        if (_ticketCount == 0) revert ZeroAmount();

        Lottery storage lottery = lotteries[currentLotteryId];

        if (lottery.endTime == 0 || block.timestamp >= lottery.endTime) revert LotteryNotActive();

        uint256 cost = lottery.ticketPrice * _ticketCount;

        // Transfer tokens from user (uses exact approval amount)
        // Note: msg.sender works correctly with EIP-7702 delegated accounts
        SafeTransferLib.safeTransferFrom(token, msg.sender, address(this), cost);

        // Add participant for each ticket (allows multiple entries)
        for (uint256 i = 0; i < _ticketCount; i++) {
            lottery.participants.push(msg.sender);
        }

        ticketCount[currentLotteryId][msg.sender] += _ticketCount;
        lottery.totalPot += cost;

        emit TicketPurchased(currentLotteryId, msg.sender, _ticketCount, cost);
    }

    /**
     * @notice End lottery and pick winner
     */
    function endLottery() external nonReentrant {
        Lottery storage lottery = lotteries[currentLotteryId];

        if (lottery.endTime == 0) revert LotteryNotActive();
        if (block.timestamp < lottery.endTime) revert LotteryNotEnded();
        if (lottery.ended) revert LotteryNotActive();

        lottery.ended = true;

        if (lottery.participants.length == 0) {
            emit WinnerSelected(currentLotteryId, address(0), 0);
            return;
        }

        // Simple randomness (use Chainlink VRF for production)
        uint256 randomIndex = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, lottery.participants.length))
        ) % lottery.participants.length;

        address winner = lottery.participants[randomIndex];
        lottery.winner = winner;

        // Calculate fee and prize
        uint256 fee = (lottery.totalPot * FEE_BPS) / MAX_BPS;
        uint256 prize = lottery.totalPot - fee;

        // Send fee to fee recipient
        SafeTransferLib.safeTransfer(token, feeRecipient, fee);
        emit FeeSent(currentLotteryId, feeRecipient, fee);

        // Send prize to winner
        SafeTransferLib.safeTransfer(token, winner, prize);
        emit WinnerSelected(currentLotteryId, winner, prize);
    }

    // ============ View Functions ============

    /**
     * @notice Get the exact cost to buy tickets
     * @param _ticketCount Number of tickets
     * @return cost Exact token amount to approve and spend
     */
    function getTicketCost(uint256 _ticketCount) external view returns (uint256 cost) {
        Lottery storage lottery = lotteries[currentLotteryId];
        return lottery.ticketPrice * _ticketCount;
    }

    function getLotteryInfo(uint256 _lotteryId)
        external
        view
        returns (
            uint256 ticketPrice,
            uint256 endTime,
            uint256 totalPot,
            uint256 participantCount,
            address winner,
            bool ended
        )
    {
        Lottery storage lottery = lotteries[_lotteryId];
        return (
            lottery.ticketPrice,
            lottery.endTime,
            lottery.totalPot,
            lottery.participants.length,
            lottery.winner,
            lottery.ended
        );
    }

    function getParticipants(uint256 _lotteryId) external view returns (address[] memory) {
        return lotteries[_lotteryId].participants;
    }

    function getTicketCount(uint256 _lotteryId, address _user) external view returns (uint256) {
        return ticketCount[_lotteryId][_user];
    }

    function isLotteryActive() external view returns (bool) {
        Lottery storage lottery = lotteries[currentLotteryId];
        return lottery.endTime > 0 && block.timestamp < lottery.endTime && !lottery.ended;
    }

    // ============ Admin Functions ============

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Emergency withdraw stuck tokens (only if lottery has no participants)
     */
    function emergencyWithdraw() external onlyOwner {
        Lottery storage lottery = lotteries[currentLotteryId];
        if (lottery.participants.length > 0) revert NoParticipants();

        uint256 balance = SafeTransferLib.balanceOf(token, address(this));
        if (balance > 0) {
            SafeTransferLib.safeTransfer(token, owner(), balance);
        }
    }
}
