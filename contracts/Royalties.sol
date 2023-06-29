// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import 'hardhat/console.sol';

interface IAeNFT {
    function originalMinters(address) external view returns(uint);
    function totalSupply() external view returns(uint);
    function reservedAmount() external view returns(uint);
}

contract Royalties is ReentrancyGuard {

    using SafeERC20 for IERC20;

    IERC20 public wmatic;

    uint256 public epoch;

    IAeNFT public nft;
    address public owner;

    mapping(uint => uint) public feesPerEpoch;
    uint256 public totalSupply;
    mapping(address => uint) public userCheckpoint;

    modifier onlyOwner {
        require(msg.sender == owner, 'not owner');
        _;
    }

    event Deposit(uint256 epoch, uint256 amount, uint256 totalSupply);
    event Claim(address indexed user, address indexed to, uint256 reward);

    constructor(address _wmatic, address _nft) {
        owner = msg.sender;
        wmatic = IERC20(_wmatic);
        nft = IAeNFT(_nft);
        epoch = 0;
    }


    function deposit(uint256 amount) external payable {
        require(amount > 0);
        require(totalSupply > 0);
        wmatic.safeTransferFrom(msg.sender, address(this), amount);

        feesPerEpoch[epoch] = amount;
        emit Deposit(epoch, amount, totalSupply);
        epoch++;
    }

    function withdrawERC20(address _token) external onlyOwner {
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, _balance);
    }


    function claim(address to) external nonReentrant {
        require(to != address(0));

        // get amount
        uint256 _toClaim = claimable(msg.sender);
        require(_toClaim <= wmatic.balanceOf(address(this)), 'too many rewards');
        require(_toClaim > 0, 'wait next');

        // update checkpoint
        userCheckpoint[msg.sender] = epoch;

        // send and enjoy
        wmatic.safeTransfer(to, _toClaim);
        emit Claim(msg.sender, to, _toClaim);
    }

    function claimable(address user) public view returns(uint) {
        uint256 cp = userCheckpoint[user];
        if(totalSupply == 0 || cp >= epoch){
            return 0;
        }

        uint i;
        uint256 _reward = 0;
        for(i = cp; i < epoch; i++){
            uint256 _fee = feesPerEpoch[i]; 
            uint256 weight = nft.originalMinters(user);
            _reward += _fee * weight / totalSupply;
        }  
        return _reward;
    }
    
    /* 
        OWNER FUNCTIONS
    */

    function setOwner(address _owner) external onlyOwner{
        require(_owner != address(0));
        owner = _owner;
    }

    function setTotalSupply() external onlyOwner{
        totalSupply = nft.totalSupply() - nft.reservedAmount();
    }

    receive() external payable {}

}