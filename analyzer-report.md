# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 2 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 3 |
| [GAS-3](#GAS-3) | State variables should be cached in stack variables rather than re-reading them from storage | 2 |
| [GAS-4](#GAS-4) | For Operations that will not overflow, you could use unchecked | 18 |
| [GAS-5](#GAS-5) | Use Custom Errors instead of Revert Strings to save Gas | 1 |
| [GAS-6](#GAS-6) | Functions guaranteed to revert when called by normal users can be marked `payable` | 2 |
| [GAS-7](#GAS-7) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 2 |
| [GAS-8](#GAS-8) | Using `private` rather than `public` for constants, saves gas | 3 |
| [GAS-9](#GAS-9) | Increments/decrements can be unchecked in for-loops | 1 |
| [GAS-10](#GAS-10) | Use != 0 instead of > 0 for unsigned integer comparison | 5 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (2)*:
```solidity
File: EmberLottery.sol

134:         ticketCount[currentLotteryId][msg.sender] += _ticketCount;

135:         lottery.totalPot += cost;

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (3)*:
```solidity
File: EmberLottery.sol

68:         if (_feeRecipient == address(0)) revert ZeroAddress();

170:             if (storedCommit == bytes32(0)) revert InvalidCommit();

267:         if (_feeRecipient == address(0)) revert ZeroAddress();

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-3"></a>[GAS-3] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (2)*:
```solidity
File: EmberLottery.sol

219:         emit FeeSent(currentLotteryId, feeRecipient, fee);

223:         emit WinnerSelected(currentLotteryId, winner, prize);

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-4"></a>[GAS-4] For Operations that will not overflow, you could use unchecked

*Instances (18)*:
```solidity
File: EmberLottery.sol

4: import {Ownable} from "solady/auth/Ownable.sol";

5: import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

6: import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

55:     uint256 public constant FEE_BPS = 500; // 5% fee

57:     uint256 public constant BLOCKHASH_ALLOWED_RANGE = 256; // Max blocks to use blockhash

95:         currentLotteryId++;

99:         lottery.endTime = block.timestamp + _duration;

100:         lottery.commitEndTime = lottery.endTime + _commitDuration;

126:         uint256 cost = lottery.ticketPrice * _ticketCount;

130:         for (uint256 i = 0; i < _ticketCount; i++) {

134:         ticketCount[currentLotteryId][msg.sender] += _ticketCount;

135:         lottery.totalPot += cost;

139:             SafeTransferLib.safeTransferETH(msg.sender, msg.value - cost);

179:                     blockhash(block.number - 1),

190:                 uint256 pastBlock = block.number - BLOCKHASH_ALLOWED_RANGE;

201:                         blockhash(block.number - 1),

214:         uint256 fee = (lottery.totalPot * FEE_BPS) / MAX_BPS;

215:         uint256 prize = lottery.totalPot - fee;

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-5"></a>[GAS-5] Use Custom Errors instead of Revert Strings to save Gas
Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (1)*:
```solidity
File: EmberLottery.sol

112:         require(block.timestamp < lottery.commitEndTime, "Commit period ended");

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-6"></a>[GAS-6] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (2)*:
```solidity
File: EmberLottery.sol

266:     function setFeeRecipient(address _feeRecipient) external onlyOwner {

274:     function emergencyWithdraw() external onlyOwner {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-7"></a>[GAS-7] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
Pre-increments and pre-decrements are cheaper.

For a `uint256 i` variable, the following is true with the Optimizer enabled at 10k:

**Increment:**

- `i += 1` is the most expensive form
- `i++` costs 6 gas less than `i += 1`
- `++i` costs 5 gas less than `i++` (11 gas less than `i += 1`)

**Decrement:**

- `i -= 1` is the most expensive form
- `i--` costs 11 gas less than `i -= 1`
- `--i` costs 5 gas less than `i--` (16 gas less than `i -= 1`)

Note that post-increments (or post-decrements) return the old value before incrementing or decrementing, hence the name *post-increment*:

```solidity
uint i = 1;  
uint j = 2;
require(j == i++, "This will be false as i is incremented after the comparison");
```
  
However, pre-increments (or pre-decrements) return the new value:
  
```solidity
uint i = 1;  
uint j = 2;
require(j == ++i, "This will be true as i is incremented before the comparison");
```

In the pre-increment case, the compiler has to create a temporary variable (when used) for returning `1` instead of `2`.

Consider using pre-increments and pre-decrements where they are relevant (meaning: not where post-increments/decrements logic are relevant).

*Saves 5 gas per instance*

*Instances (2)*:
```solidity
File: EmberLottery.sol

95:         currentLotteryId++;

130:         for (uint256 i = 0; i < _ticketCount; i++) {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-8"></a>[GAS-8] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (3)*:
```solidity
File: EmberLottery.sol

55:     uint256 public constant FEE_BPS = 500; // 5% fee

56:     uint256 public constant MAX_BPS = 10000;

57:     uint256 public constant BLOCKHASH_ALLOWED_RANGE = 256; // Max blocks to use blockhash

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-9"></a>[GAS-9] Increments/decrements can be unchecked in for-loops
In Solidity 0.8+, there's a default overflow check on unsigned integers. It's possible to uncheck this in for-loops and save some gas at each iteration, but at the cost of some code readability, as this uncheck cannot be made inline.

[ethereum/solidity#10695](https://github.com/ethereum/solidity/issues/10695)

The change would be:

```diff
- for (uint256 i; i < numIterations; i++) {
+ for (uint256 i; i < numIterations;) {
 // ...  
+   unchecked { ++i; }
}  
```

These save around **25 gas saved** per instance.

The same can be applied with decrements (which should use `break` when `i == 0`).

The risk of overflow is non-existent for `uint256`.

*Instances (1)*:
```solidity
File: EmberLottery.sol

130:         for (uint256 i = 0; i < _ticketCount; i++) {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="GAS-10"></a>[GAS-10] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (5)*:
```solidity
File: EmberLottery.sol

90:         if (currentLotteryId > 0) {

167:         if (lottery.commitEndTime > 0 && block.timestamp >= lottery.commitEndTime) {

261:         return lottery.endTime > 0 && block.timestamp < lottery.endTime && !lottery.ended;

276:         if (lottery.participants.length > 0) revert NoParticipants();

279:         if (balance > 0) {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked` | 4 |
| [NC-2](#NC-2) | Control structures do not follow the Solidity Style Guide | 13 |
| [NC-3](#NC-3) | Consider disabling `renounceOwnership()` | 1 |
| [NC-4](#NC-4) | Unused `error` definition | 2 |
| [NC-5](#NC-5) | Functions should not be longer than 50 lines | 7 |
| [NC-6](#NC-6) | Missing Event for critical parameters change | 1 |
| [NC-7](#NC-7) | NatSpec is completely non-existent on functions that should have them | 1 |
| [NC-8](#NC-8) | Consider using named mappings | 4 |
| [NC-9](#NC-9) | Adding a `return` statement when the function defines a named return variable, is redundant | 1 |
| [NC-10](#NC-10) | Take advantage of Custom Error's return value property | 13 |
| [NC-11](#NC-11) | Contract does not follow the Solidity style guide's suggested layout ordering | 1 |
| [NC-12](#NC-12) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-13](#NC-13) | Event is missing `indexed` fields | 5 |
| [NC-14](#NC-14) | Variables need not be initialized to zero | 1 |
### <a name="NC-1"></a>[NC-1] Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked`
Solidity version 0.8.4 introduces `bytes.concat()` (vs `abi.encodePacked(<bytes>,<bytes>)`)

Solidity version 0.8.12 introduces `string.concat()` (vs `abi.encodePacked(<str>,<str>), which catches concatenation errors (in the event of a `bytes` data mixed in the concatenation)`)

*Instances (4)*:
```solidity
File: EmberLottery.sol

172:             bytes32 expectedCommit = keccak256(abi.encodePacked(_secret, msg.sender));

177:                 keccak256(abi.encodePacked(

192:                     keccak256(abi.encodePacked(

200:                     keccak256(abi.encodePacked(

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-2"></a>[NC-2] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (13)*:
```solidity
File: EmberLottery.sol

68:         if (_feeRecipient == address(0)) revert ZeroAddress();

86:         if (_ticketPrice == 0) revert InvalidTicketPrice();

87:         if (_duration == 0) revert InvalidDuration();

92:             if (!prev.ended && block.timestamp < prev.endTime) revert LotteryAlreadyActive();

124:         if (lottery.endTime == 0 || block.timestamp >= lottery.endTime) revert LotteryNotActive();

127:         if (msg.value < cost) revert InsufficientPayment();

152:         if (lottery.endTime == 0) revert LotteryNotActive();

153:         if (block.timestamp < lottery.endTime) revert LotteryNotEnded();

154:         if (lottery.ended) revert LotteryNotActive();

170:             if (storedCommit == bytes32(0)) revert InvalidCommit();

173:             if (storedCommit != expectedCommit) revert InvalidCommit();

267:         if (_feeRecipient == address(0)) revert ZeroAddress();

276:         if (lottery.participants.length > 0) revert NoParticipants();

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-3"></a>[NC-3] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (1)*:
```solidity
File: EmberLottery.sol

19: contract EmberLottery is Ownable, ReentrancyGuard {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-4"></a>[NC-4] Unused `error` definition
Note that there may be cases where an error superficially appears to be used, but this is only because there are multiple definitions of the error in different files. In such cases, the error definition should be moved into a separate file. The instances below are the unused definitions.

*Instances (2)*:
```solidity
File: EmberLottery.sol

28:     error TransferFailed();

31:     error RevealTooEarly();

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-5"></a>[NC-5] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (7)*:
```solidity
File: EmberLottery.sol

110:     function commit(uint256 _lotteryId, bytes32 _commitHash) external {

121:     function buyTickets(uint256 _ticketCount) external payable nonReentrant {

149:     function endLottery(bytes calldata _secret) external nonReentrant {

251:     function getParticipants(uint256 _lotteryId) external view returns (address[] memory) {

255:     function getTicketCount(uint256 _lotteryId, address _user) external view returns (uint256) {

259:     function isLotteryActive() external view returns (bool) {

266:     function setFeeRecipient(address _feeRecipient) external onlyOwner {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-6"></a>[NC-6] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (1)*:
```solidity
File: EmberLottery.sol

266:     function setFeeRecipient(address _feeRecipient) external onlyOwner {
             if (_feeRecipient == address(0)) revert ZeroAddress();
             feeRecipient = _feeRecipient;

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-7"></a>[NC-7] NatSpec is completely non-existent on functions that should have them
Public and external functions that aren't view or pure should have NatSpec comments

*Instances (1)*:
```solidity
File: EmberLottery.sol

266:     function setFeeRecipient(address _feeRecipient) external onlyOwner {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-8"></a>[NC-8] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (4)*:
```solidity
File: EmberLottery.sol

50:         mapping(address => bytes32) commits;

51:         mapping(address => uint256) ticketCountPerUser;

63:     mapping(uint256 => Lottery) public lotteries;

64:     mapping(uint256 => mapping(address => uint256)) public ticketCount;

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-9"></a>[NC-9] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (1)*:
```solidity
File: EmberLottery.sol

228:     function getLotteryInfo(uint256 _lotteryId)
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

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-10"></a>[NC-10] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (13)*:
```solidity
File: EmberLottery.sol

68:         if (_feeRecipient == address(0)) revert ZeroAddress();

86:         if (_ticketPrice == 0) revert InvalidTicketPrice();

87:         if (_duration == 0) revert InvalidDuration();

92:             if (!prev.ended && block.timestamp < prev.endTime) revert LotteryAlreadyActive();

124:         if (lottery.endTime == 0 || block.timestamp >= lottery.endTime) revert LotteryNotActive();

127:         if (msg.value < cost) revert InsufficientPayment();

152:         if (lottery.endTime == 0) revert LotteryNotActive();

153:         if (block.timestamp < lottery.endTime) revert LotteryNotEnded();

154:         if (lottery.ended) revert LotteryNotActive();

170:             if (storedCommit == bytes32(0)) revert InvalidCommit();

173:             if (storedCommit != expectedCommit) revert InvalidCommit();

267:         if (_feeRecipient == address(0)) revert ZeroAddress();

276:         if (lottery.participants.length > 0) revert NoParticipants();

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-11"></a>[NC-11] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (1)*:
```solidity
File: EmberLottery.sol

1: 
   Current order:
   ErrorDefinition.LotteryNotActive
   ErrorDefinition.LotteryNotEnded
   ErrorDefinition.LotteryAlreadyActive
   ErrorDefinition.InvalidTicketPrice
   ErrorDefinition.InvalidDuration
   ErrorDefinition.NoParticipants
   ErrorDefinition.InsufficientPayment
   ErrorDefinition.TransferFailed
   ErrorDefinition.ZeroAddress
   ErrorDefinition.InvalidCommit
   ErrorDefinition.RevealTooEarly
   EventDefinition.LotteryStarted
   EventDefinition.TicketPurchased
   EventDefinition.WinnerSelected
   EventDefinition.FeeSent
   EventDefinition.Committed
   StructDefinition.Lottery
   VariableDeclaration.FEE_BPS
   VariableDeclaration.MAX_BPS
   VariableDeclaration.BLOCKHASH_ALLOWED_RANGE
   VariableDeclaration.currentLotteryId
   VariableDeclaration.feeRecipient
   VariableDeclaration.lotteries
   VariableDeclaration.ticketCount
   FunctionDefinition.constructor
   FunctionDefinition.startLottery
   FunctionDefinition.commit
   FunctionDefinition.buyTickets
   FunctionDefinition.endLottery
   FunctionDefinition.getLotteryInfo
   FunctionDefinition.getParticipants
   FunctionDefinition.getTicketCount
   FunctionDefinition.isLotteryActive
   FunctionDefinition.setFeeRecipient
   FunctionDefinition.emergencyWithdraw
   
   Suggested order:
   VariableDeclaration.FEE_BPS
   VariableDeclaration.MAX_BPS
   VariableDeclaration.BLOCKHASH_ALLOWED_RANGE
   VariableDeclaration.currentLotteryId
   VariableDeclaration.feeRecipient
   VariableDeclaration.lotteries
   VariableDeclaration.ticketCount
   StructDefinition.Lottery
   ErrorDefinition.LotteryNotActive
   ErrorDefinition.LotteryNotEnded
   ErrorDefinition.LotteryAlreadyActive
   ErrorDefinition.InvalidTicketPrice
   ErrorDefinition.InvalidDuration
   ErrorDefinition.NoParticipants
   ErrorDefinition.InsufficientPayment
   ErrorDefinition.TransferFailed
   ErrorDefinition.ZeroAddress
   ErrorDefinition.InvalidCommit
   ErrorDefinition.RevealTooEarly
   EventDefinition.LotteryStarted
   EventDefinition.TicketPurchased
   EventDefinition.WinnerSelected
   EventDefinition.FeeSent
   EventDefinition.Committed
   FunctionDefinition.constructor
   FunctionDefinition.startLottery
   FunctionDefinition.commit
   FunctionDefinition.buyTickets
   FunctionDefinition.endLottery
   FunctionDefinition.getLotteryInfo
   FunctionDefinition.getParticipants
   FunctionDefinition.getTicketCount
   FunctionDefinition.isLotteryActive
   FunctionDefinition.setFeeRecipient
   FunctionDefinition.emergencyWithdraw

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-12"></a>[NC-12] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:
```solidity
File: EmberLottery.sol

56:     uint256 public constant MAX_BPS = 10000;

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-13"></a>[NC-13] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (5)*:
```solidity
File: EmberLottery.sol

34:     event LotteryStarted(uint256 indexed lotteryId, uint256 ticketPrice, uint256 endTime);

35:     event TicketPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 ticketCount);

36:     event WinnerSelected(uint256 indexed lotteryId, address indexed winner, uint256 prize);

37:     event FeeSent(uint256 indexed lotteryId, address indexed feeRecipient, uint256 amount);

38:     event Committed(uint256 indexed lotteryId, address indexed participant, bytes32 commit);

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="NC-14"></a>[NC-14] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (1)*:
```solidity
File: EmberLottery.sol

130:         for (uint256 i = 0; i < _ticketCount; i++) {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 1 |
| [L-2](#L-2) | `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 1 |
| [L-3](#L-3) | Loss of precision | 1 |
| [L-4](#L-4) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 1 |
| [L-5](#L-5) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 1 |
| [L-6](#L-6) | Upgradeable contract not initialized | 1 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (1)*:
```solidity
File: EmberLottery.sol

19: contract EmberLottery is Ownable, ReentrancyGuard {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="L-2"></a>[L-2] `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`
Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). "Unless there is a compelling reason, `abi.encode` should be preferred". If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead

*Instances (1)*:
```solidity
File: EmberLottery.sol

172:             bytes32 expectedCommit = keccak256(abi.encodePacked(_secret, msg.sender));

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="L-3"></a>[L-3] Loss of precision
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (1)*:
```solidity
File: EmberLottery.sol

214:         uint256 fee = (lottery.totalPot * FEE_BPS) / MAX_BPS;

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="L-4"></a>[L-4] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (1)*:
```solidity
File: EmberLottery.sol

2: pragma solidity ^0.8.20;

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="L-5"></a>[L-5] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
Use [Ownable2Step.transferOwnership](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol) which is safer. Use it as it is more secure due to 2-stage ownership transfer.

**Recommended Mitigation Steps**

Use <a href="https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol">Ownable2Step.sol</a>
  
  ```solidity
      function acceptOwnership() external {
          address sender = _msgSender();
          require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
          _transferOwnership(sender);
      }
```

*Instances (1)*:
```solidity
File: EmberLottery.sol

4: import {Ownable} from "solady/auth/Ownable.sol";

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="L-6"></a>[L-6] Upgradeable contract not initialized
Upgradeable contracts are initialized via an initializer function rather than by a constructor. Leaving such a contract uninitialized may lead to it being taken over by a malicious user

*Instances (1)*:
```solidity
File: EmberLottery.sol

69:         _initializeOwner(msg.sender);

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | `block.number` means different things on different L2s | 4 |
| [M-2](#M-2) | Centralization Risk for trusted owners | 4 |
### <a name="M-1"></a>[M-1] `block.number` means different things on different L2s
On Optimism, `block.number` is the L2 block number, but on Arbitrum, it's the L1 block number, and `ArbSys(address(100)).arbBlockNumber()` must be used. Furthermore, L2 block numbers often occur much more frequently than L1 block numbers (any may even occur on a per-transaction basis), so using block numbers for timing results in inconsistencies, especially when voting is involved across multiple chains. As of version 4.9, OpenZeppelin has [modified](https://blog.openzeppelin.com/introducing-openzeppelin-contracts-v4.9#governor) their governor code to use a clock rather than block numbers, to avoid these sorts of issues, but this still requires that the project [implement](https://docs.openzeppelin.com/contracts/4.x/governance#token_2) a [clock](https://eips.ethereum.org/EIPS/eip-6372) for each L2.

*Instances (4)*:
```solidity
File: EmberLottery.sol

179:                     blockhash(block.number - 1),

189:             if (block.number > BLOCKHASH_ALLOWED_RANGE) {

190:                 uint256 pastBlock = block.number - BLOCKHASH_ALLOWED_RANGE;

201:                         blockhash(block.number - 1),

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

### <a name="M-2"></a>[M-2] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (4)*:
```solidity
File: EmberLottery.sol

19: contract EmberLottery is Ownable, ReentrancyGuard {

85:     ) external onlyOwner {

266:     function setFeeRecipient(address _feeRecipient) external onlyOwner {

274:     function emergencyWithdraw() external onlyOwner {

```
[Link to code](https://github.com/emberdragonc/ember-lotteryEmberLottery.sol)

