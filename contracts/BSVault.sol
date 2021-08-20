pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract BSVault is Context, ReentrancyGuard {
    address private factory;
    IERC20 private hold_token;
    uint256 public unlockDate;
    uint256 private price;
    uint256 private longLock;
    bool public isEnabled;
    address private _owner;

    using SafeERC20 for IERC20;
    using SafeMath  for uint256;

    //event StakedToken(uint256 _amount);
    event WithdrewTokens(uint256 _amount);

    constructor(address _NewOwner, uint256 _price, uint256 _longLock, address _factory, IERC20 _hold_token) {
        _owner = _NewOwner;
        price = _price;
        longLock = _longLock;
        factory = _factory;
        hold_token = _hold_token;
        isEnabled = false;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function info() public view returns(address _factory, address owners, uint256 _unlockDate, uint256 _balance, uint256 _price) {
        _factory = factory;
        owners = owner();
        _unlockDate = unlockDate;
        _balance = IERC20(hold_token).balanceOf(address(this));
        _price = price;
    }

    /**
     * @dev Make stake on vault with timelock.
     */
    function stakeVault() onlyOwner public nonReentrant {
        require(isEnabled == false, "BSVault: VAULT_WAS_STAKED");
        require(IERC20(hold_token).balanceOf(_msgSender()) >= price, "BSVault: USER_NOT_ENOUGHT_BST");
        _stake(hold_token, price);
        unlockDate = longLock.add(block.timestamp);
        isEnabled = true;
        //StakedToken(unlockDate);
    }

    /**
     * @dev Make withdraw from vault after timelock end's.
     */
    function withdrawVault() onlyOwner public nonReentrant {
        require(isEnabled == true, "BSVault: VAULT_WAS_NOT_STAKED");
        require(block.timestamp >= unlockDate, "BSVault: VAULT_TIMELOCKED");
        uint256 tokenBalance = IERC20(hold_token).balanceOf(address(this));
        _send(hold_token, tokenBalance);
        isEnabled = false;
        emit WithdrewTokens(tokenBalance);
    }

    /**
      * @dev Privates functions
      */

    // send tokens from contract
    function _send(IERC20 token, uint256 amount) internal {
        SafeERC20.safeTransfer(token, owner(), amount);
    }

    // request tokens from user
    function _stake(IERC20 token, uint256 amount) internal {
        uint256 allow_amount = IERC20(token).allowance(_msgSender(), address(this));
        require(amount <= allow_amount, 'BSVault: NOT_APPROVED_AMOUNT');

        SafeERC20.safeTransferFrom(token, _msgSender(), address(this), amount);
    }

}
