// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title EmberLottery
 * @author Ember 🐉
 * @notice Simple lottery where users buy tickets with ETH, winner takes pot minus fee
 * @dev Built with Solady for gas efficiency.
 *
 * @dev RANDOMNESS LIMITATIONS (from @dragon_bot_z audit):
 *      - Commit-reveal provides basic front-running protection but revealer can influence timing
 *      - For high-stakes lotteries (>10 ETH), integrate Chainlink VRF
 *      - Current implementation acceptable for small-medium pots with documented caveats
 *
 * @dev Audit fixes:
 *      - BLOCKHASH_ALLOWED_RANGE check for randomness (@Clawditor)
 *      - Front-running protection with commit-reveal scheme (@Clawditor)
 *      - Removed unused state variables (@dragon_bot_z)
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
    error InvalidCommit();
    error RevealTooEarly();

    // ============ Events ============
    event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice, uint256 endTime);
    event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketCount);
    event WinnerSelected(uint256 indexed lotteryId, address indexed winner, uint256 prize);
    event FeeSent(uint256 indexed lotteryId, address indexed feeRecipient, uint256 amount);
    event Committed(uint256 indexed lotteryId, address indexed participant, bytes32 commit);

    // ============ Structs ============
    struct Lottery {
        uint256 ticketPrice;
        uint256 endTime;
        uint256 totalPot;
        address[] participants;
        address winner;
        bool ended;
        // Commit-reveal for front-running protection
        uint256 commitEndTime;
        mapping(address => bytes32) commits;
        // Note: ticketCount is tracked at contract level, not per-lottery struct
    }

    // ============ Constants ============
    uint256 public constant FEE_BPS = 500; // 5% fee
    uint256 public constant MAX_BPS = 10000;
    uint256 public constant BLOCKHASH_ALLOWED_RANGE = 256; // Max blocks to use blockhash

    // ============ State ============
    uint256 public currentLotteryId;
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
     * @param _commitDuration Duration for commit phase before ticket sales end (seconds)
     */
    function startLottery(uint256 _ticketPrice, uint256 _duration, uint256 _commitDuration) external onlyOwner {
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
        // Only enable commit-reveal if commitDuration > 0
        if (_commitDuration > 0) {
            lottery.commitEndTime = lottery.endTime + _commitDuration;
        }

        emit LotteryStarted(currentLotteryId, _ticketPrice, lottery.endTime);
    }

    /**
     * @notice Commit hash for randomness (front-running protection)
     * @param _lotteryId Lottery ID
     * @param _commitHash keccak256(abi.encodePacked(secret, userAddress))
     */
    function commit(uint256 _lotteryId, bytes32 _commitHash) external {
        Lottery storage lottery = lotteries[_lotteryId];
        require(block.timestamp < lottery.commitEndTime, "Commit period ended");
        lottery.commits[msg.sender] = _commitHash;
        emit Committed(_lotteryId, msg.sender, _commitHash);
    }

    /**
     * @notice Buy tickets for the current lottery
     * @param _ticketCount Number of tickets to buy
     * @dev Note: Current implementation pushes each ticket individually to participants array.
     *      For gas optimization with large ticket purchases, consider ticket ranges:
     *      struct TicketRange { address buyer; uint256 startIndex; uint256 endIndex; }
     *      This would reduce storage writes from O(n) to O(1) per purchase.
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
     * @param _secret User's secret used to generate commit hash
     */
    function endLottery(bytes calldata _secret) external nonReentrant {
        Lottery storage lottery = lotteries[currentLotteryId];

        if (lottery.endTime == 0) revert LotteryNotActive();
        if (block.timestamp < lottery.endTime) revert LotteryNotEnded();
        if (lottery.ended) revert LotteryNotActive();

        lottery.ended = true;

        if (lottery.participants.length == 0) {
            emit WinnerSelected(currentLotteryId, address(0), 0);
            return;
        }

        // Audit fix: Use commit-reveal for randomness if commits exist
        // Fallback to blockhash if no commits
        address winner;

        if (lottery.commitEndTime > 0 && block.timestamp >= lottery.commitEndTime) {
            // Verify commit
            bytes32 storedCommit = lottery.commits[msg.sender];
            if (storedCommit == bytes32(0)) revert InvalidCommit();

            bytes32 expectedCommit = keccak256(abi.encodePacked(_secret, msg.sender));
            if (storedCommit != expectedCommit) revert InvalidCommit();

            // Use commit + blockhash for randomness
            uint256 randomIndex = uint256(
                keccak256(abi.encodePacked(storedCommit, blockhash(block.number - 1), block.timestamp))
            ) % lottery.participants.length;

            winner = lottery.participants[randomIndex];
        } else {
            // Audit fix: Check blockhash availability
            // blockhash is only valid for the last 256 blocks
            uint256 randomIndex;
            if (block.number > BLOCKHASH_ALLOWED_RANGE) {
                uint256 pastBlock = block.number - BLOCKHASH_ALLOWED_RANGE;
                randomIndex = uint256(
                    keccak256(abi.encodePacked(blockhash(pastBlock), block.timestamp, lottery.participants.length))
                ) % lottery.participants.length;
            } else {
                randomIndex = uint256(
                    keccak256(
                        abi.encodePacked(blockhash(block.number - 1), block.timestamp, lottery.participants.length)
                    )
                ) % lottery.participants.length;
            }

            winner = lottery.participants[randomIndex];
        }

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
