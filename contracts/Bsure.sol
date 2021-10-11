pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BSURE is Context, Ownable, ReentrancyGuard {

    uint256 private count_deposit;
    uint256 private reinvested;
    uint256 private requested;

    struct Info {
       address holder;
       uint8 plan_status;
       uint256 amount;
       uint8 status;
       uint256 lock_time;
    }

    mapping(uint256 => Info) vaults;
    mapping(address => uint256) holder_storage;

    uint256 private price_1;
    uint256 private price_2;
    uint256 private longLock;
    IERC20 private deposit_token;

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Deposited(uint256 vault, address from, uint256 amount);
    event Withdrew(uint256 vault, uint256 amount);
    event Requested(uint256 vault);

    constructor(uint256 _price_1, uint256 _price_2, uint256 _longLock, IERC20 _hold_token) {
        price_1 = _price_1;
        price_2 = _price_2;
        longLock = _longLock;
        deposit_token = _hold_token;
        count_deposit = 0;
    }

    function getStorageId(address _user) public view returns(uint256 _holder_storage) {
        _holder_storage = holder_storage[_user];
    }

    function getInfo(uint256 _id) public view returns(Info memory _storage_info) {
        _storage_info = vaults[_id];
    }

    /**
     * @dev Make stake on contract.
     */
    function Deposit_plan_1() payable public nonReentrant {
        require(getStorageId(_msgSender()) == 0, "BSURE: DEPOSIT_EXISTS");
        _stake(deposit_token, price_1);

        uint256 new_id = count_deposit.add(1);
        _setStorage(new_id);
        uint256 timeLock = longLock.add(block.timestamp);
        _setInfo(new_id, 1, timeLock);
        count_deposit = new_id;
        emit Deposited(new_id, _msgSender(), price_1);
    }

    function Deposit_plan_2() payable public nonReentrant {
        require(getStorageId(_msgSender()) == 0, "BSURE: DEPOSIT_EXISTS");
        _stake(deposit_token, price_2);

        uint256 new_id = count_deposit.add(1);
        _setStorage(new_id);
        uint256 timeLock = longLock.add(block.timestamp);
        _setInfo(new_id, 2, timeLock);
        count_deposit = new_id;
        emit Deposited(new_id, _msgSender(), price_2);
    }

    /**
     * @dev Make withdraw from vault.
     */
    function withdrawVault() public nonReentrant {
        uint256 vault_id = getStorageId(_msgSender());
        require(vault_id != 0, "BSURE: DEPOSIT_DOESNT_EXIST");
        Info memory vault_info = getInfo(vault_id);
        if (vault_info.lock_time >= block.timestamp) {
          if (vault_info.status == 2) {
            _newRequest(vault_id, vault_info.amount);
            emit Requested(vault_id);
          }
        } else {
          _send(deposit_token, _msgSender(), vault_info.amount);
          vaults[vault_id].status = 0;
          _setStorage(0);
          emit Withdrew(vault_id, vault_info.amount);
        }
    }

    /**
     * @dev Make withdraw from vault.
     */
    function reinvestVault() public nonReentrant {
        uint256 vault_id = getStorageId(_msgSender());
        require(vault_id != 0, "BSURE: DEPOSIT_DOESNT_EXIST");
        Info memory vault_info = getInfo(vault_id);
        require(vault_info.status == 2, "BSURE: DEPOSIT_REQUESTED_WITHDRAW");
        require(vault_info.lock_time <= block.timestamp, "BSURE: DEPOSIT_CURRENTLY_ACTIVE");
        require(vault_info.lock_time.add(604800) >= block.timestamp, "BSURE: DEPOSIT_MUST_BE_WITHDRAW");
        vaults[vault_id].lock_time = vault_info.lock_time.add(longLock);
    }


    /**
      * @dev Admin functions
      */

    function ReInvest(uint256 amount, address to) onlyOwner public nonReentrant {
        _send(deposit_token, to, amount);
        reinvested = reinvested.add(amount);
    }

    function BackInvest(uint256 amount) onlyOwner public nonReentrant {
        _stake(deposit_token, amount);
        reinvested = reinvested.sub(amount);
    }

    function BackRequest(uint256 amount) onlyOwner public nonReentrant {
        _stake(deposit_token, amount);
        reinvested = reinvested.sub(amount);
        requested = requested.sub(amount);
    }

    /**
      * @dev Privates functions
      */
    // set Info to Vault
    function _setInfo(uint256 _id, uint8 _plan_status, uint256 _lock_time) internal {
        if (_plan_status == 1) {
          vaults[_id] = Info(_msgSender(), _plan_status, price_1, 2, _lock_time);
        } else {
          vaults[_id] = Info(_msgSender(), _plan_status, price_2, 2, _lock_time);
        }

    }

    // set storage_id for holder
    function _setStorage(uint256 _id) internal {
        holder_storage[_msgSender()] = _id;
    }

    // create pre-time Withdraw request
    function _newRequest(uint256 _id, uint256 _amount) internal {
        uint256 secure_time = block.timestamp; //.add(259200);
        vaults[_id].status = 1;
        vaults[_id].lock_time = secure_time;
        //+ make request array
        requested = requested.add(_amount);
    }

    // send tokens from contract
    function _send(IERC20 token, address to, uint256 amount) internal {
        require(amount > 0, 'BSURE: INSUFFICIENT_AMOUNT');
        require(IERC20(token).balanceOf(address(this)) >= amount, "BSURE: CONTRACT_NOT_ENOUGHT_TOKEN");

        SafeERC20.safeTransfer(token, to, amount);
    }

    // request tokens from user
    function _stake(IERC20 token, uint256 amount) internal {
        require(amount > 0, 'BSURE: INSUFFICIENT_AMOUNT');
        require(IERC20(token).balanceOf(_msgSender()) >= amount, "BSURE: USER_NOT_ENOUGHT_TOKEN");
        uint256 allow_amount = IERC20(token).allowance(_msgSender(), address(this));
        require(amount <= allow_amount, "BSURE: NOT_APPROVED_AMOUNT");

        SafeERC20.safeTransferFrom(token, _msgSender(), address(this), amount);
    }


}
