// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title EmberLottery
 * @author Ember 🐉
 * @notice Simple lottery where users buy tickets with ETH, winner takes pot minus fee
 * @dev Built with Solady for gas efficiency. Uses block hash for randomness (simple version).
 *      For production, integrate Chainlink VRF.
 */
contract EmberLottery is Ownable, ReentrancyGuard {
    // ============ Errors ============
    error LotteryNotActive();
    error LotteryNotEnded();
    error LotteryAlreadyActive();
    error InvalidTicketPrice();
    error InvalidDuration();
    error NoParticipants();
    error InsufficientPayment();
    error TransferFailed();
    error ZeroAddress();

    // ============ Events ============
    event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice, uint256 endTime);
    event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketCount);
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

    // ============ State ============
    uint256 public currentLotteryId;
    uint256 public constant FEE_BPS = 500; // 5% fee
    uint256 public constant MAX_BPS = 10000;

    address public feeRecipient;

    mapping(uint256 => Lottery) public lotteries;
    mapping(uint256 => mapping(address => uint256)) public ticketCount;

    // ============ Constructor ============
    constructor(address _feeRecipient) {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        _initializeOwner(msg.sender);
        feeRecipient = _feeRecipient;
    }

    // ============ External Functions ============

    /**
     * @notice Start a new lottery
     * @param _ticketPrice Price per ticket in wei
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
     */
    function buyTickets(uint256 _ticketCount) external payable nonReentrant {
        Lottery storage lottery = lotteries[currentLotteryId];

        if (lottery.endTime == 0 || block.timestamp >= lottery.endTime) revert LotteryNotActive();

        uint256 cost = lottery.ticketPrice * _ticketCount;
        if (msg.value < cost) revert InsufficientPayment();

        // Add participant for each ticket (allows multiple entries)
        for (uint256 i = 0; i < _ticketCount; i++) {
            lottery.participants.push(msg.sender);
        }

        ticketCount[currentLotteryId][msg.sender] += _ticketCount;
        lottery.totalPot += cost;

        // Refund excess
        if (msg.value > cost) {
            SafeTransferLib.safeTransferETH(msg.sender, msg.value - cost);
        }

        emit TicketPurchased(currentLotteryId, msg.sender, _ticketCount);
    }

    /**
     * @notice End lottery and pick winner
     * @dev Uses block hash for randomness. For production, use Chainlink VRF.
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

        // Send fee to fee recipient (staking contract)
        SafeTransferLib.safeTransferETH(feeRecipient, fee);
        emit FeeSent(currentLotteryId, feeRecipient, fee);

        // Send prize to winner
        SafeTransferLib.safeTransferETH(winner, prize);
        emit WinnerSelected(currentLotteryId, winner, prize);
    }

    // ============ View Functions ============

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
     * @notice Emergency withdraw (only if lottery has no participants)
     */
    function emergencyWithdraw() external onlyOwner {
        Lottery storage lottery = lotteries[currentLotteryId];
        if (lottery.participants.length > 0) revert NoParticipants();

        uint256 balance = address(this).balance;
        if (balance > 0) {
            SafeTransferLib.safeTransferETH(owner(), balance);
        }
    }
}
