pragma solidity ^0.8.4;
import "./BSVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract BSVaultFactory is Context, Ownable {

    mapping(address => address[]) vaults;

    address public implementation;
    uint256 private price;
    uint256 private longLock;
    IERC20 private hold_token;

    event Created(address vault, address from);

    constructor(uint256 _price, uint256 _longLock, IERC20 _hold_token, address _implementation) {
        price = _price;
        longLock = _longLock;
        hold_token = _hold_token;
        implementation = _implementation;
    }

    function getVault(address _user) public view returns(address[] memory _vault) {
        _vault = vaults[_user];
    }

    function newSettings(uint256 _price, uint256 _longLock, IERC20 _hold_token) onlyOwner public {
        price = _price;
        longLock = _longLock;
        hold_token = _hold_token;
    }

    function newBSVault() payable public returns(address) {
        address vault = Clones.clone(implementation);
        //address vault = new BSVault(_msgSender(), price, longLock, address(this), hold_token);
        vaults[_msgSender()].push(vault);
        emit Created(address(vault), _msgSender());
        return address(vault);
    }

}
