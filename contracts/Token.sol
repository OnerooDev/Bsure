pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract newToken is Context, AccessControlEnumerable, ERC20Burnable, ERC20Pausable, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    using SafeERC20 for IERC20;
    using SafeMath  for uint256;

    IERC20 public token_usdt;
    uint256 public reinvested;

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC20-constructor}.
     */
    constructor(string memory name, string memory symbol, IERC20 _token_usdt) ERC20(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        token_usdt = _token_usdt;
    }

    /**
     * @dev Allow a user to deposit USDT tokens and mint the corresponding number of wrapped tokens.
     */
    function depositFor(uint256 amount) public virtual nonReentrant returns (bool) {
        require(amount > 0, 'BSURE: INSUFFICIENT_AMOUNT');
        require(IERC20(token_usdt).balanceOf(_msgSender()) >= amount, "BSURE: USER_NOT_ENOUGHT_USDT");

        _stake(token_usdt, amount);
        _mint(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Allow a user to burn a number of wrapped tokens and withdraw the corresponding number of USDT tokens.
     */
    function withdrawTo(uint256 amount) public virtual nonReentrant returns (bool) {
        require(amount > 0, 'BSURE: INSUFFICIENT_AMOUNT');
        require(IERC20(address(this)).balanceOf(_msgSender()) >= amount, "BSURE: USER_NOT_ENOUGHT_BST");
        require(IERC20(token_usdt).balanceOf(address(this)) >= amount, "BSURE: BSURE_NOT_ENOUGHT_USDT");

        _burn(_msgSender(), amount);
        _send(token_usdt, amount);
        return true;
    }

    /**
     * @dev Allow a reinvest USDT tokens for admin.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function ReInvest(IERC20 invest_token, uint256 amount) public virtual nonReentrant returns (bool) {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
        require(amount > 0, 'BSURE: INSUFFICIENT_AMOUNT');
        require(IERC20(invest_token).balanceOf(address(this)) >= amount, "BSURE: BSURE_NOT_ENOUGHT_TOKEN");

        _send(invest_token, amount);
        reinvested = reinvested.add(amount);
        return true;
    }

    /**
     * @dev Allow a reinvest USDT tokens for admin.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function BackInvest(IERC20 invest_token, uint256 amount) public virtual nonReentrant returns (bool) {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
        require(amount > 0, 'BSURE: INSUFFICIENT_AMOUNT');
        require(IERC20(invest_token).balanceOf(_msgSender()) >= amount, "BSURE: BSURE_NOT_ENOUGHT_TOKEN");

        _stake(invest_token, amount);
        reinvested = reinvested.sub(amount);
        return true;
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to unpause");
        _unpause();
    }

    /**
      * @dev Privates functions
      */

    // send tokens from contract
    function _send(IERC20 token, uint256 amount) internal {
        SafeERC20.safeTransfer(token, _msgSender(), amount);
    }

    // request tokens from user
    function _stake(IERC20 token, uint256 amount) internal {
        uint256 allow_amount = IERC20(token).allowance(_msgSender(), address(this));
        require(amount <= allow_amount, 'BSURE: NOT_APPROVED_AMOUNT');

        SafeERC20.safeTransferFrom(token, _msgSender(), address(this), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
