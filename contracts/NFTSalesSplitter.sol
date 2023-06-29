// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import './interfaces/IERC20.sol';

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


interface IRoyalties{
    function deposit(uint256 amount) external;
}
interface IWMATIC{
     function deposit() external payable ;
}

interface IStakingNFTConverter {
    function claimFees() external;
    function swap() external;
}

// The base pair of pools, either stable or volatile
contract NFTSalesSplitter is OwnableUpgradeable  {

    uint256 constant public PRECISION = 1000;
    uint256 public converterFee;
    uint256 public royaltiesFee;
    

    address public wmatic;
    
    address public stakingConverter;
    address public royalties;


    mapping(address => bool) public splitter;


    event Split(uint256 indexed timestamp, uint256 toStake, uint256 toRoyalties);
    
    modifier onlyAllowed() {
        require(msg.sender == owner() || splitter[msg.sender]);
        _;
    }

    constructor() {}

    function initialize(address _stakingConverter, address _royalties) initializer  public {
        __Ownable_init();
        wmatic = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        stakingConverter = address(_stakingConverter);
        royalties = address(_royalties);
        converterFee = 333;
        royaltiesFee = 667;
    }

    function split() public onlyAllowed {

        // convert matic to wmatic, easier to handle
        if(address(this).balance > 0){
            IWMATIC(wmatic).deposit{value: address(this).balance}();
        }

        uint256 balance = balanceOf();
        uint256 stakingAmount = 0;
        uint256 royaltiesAmount = 0;

        if(stakingConverter != address(0)){
            stakingAmount = balance * converterFee / PRECISION;
            IERC20(wmatic).transfer(stakingConverter, stakingAmount);
            IStakingNFTConverter(stakingConverter).claimFees();
            IStakingNFTConverter(stakingConverter).swap();
        }

        if(royalties != address(0)){
            royaltiesAmount = balance * royaltiesFee / PRECISION;
            IERC20(wmatic).approve(royalties, 0);
            IERC20(wmatic).approve(royalties, royaltiesAmount);
            IRoyalties(royalties).deposit(royaltiesAmount);
        }
        emit Split(block.timestamp, stakingAmount, royaltiesAmount);    

    }

    function balanceOf() public view returns(uint){
        return IERC20(wmatic).balanceOf(address(this));
    }

    function setConverter(address _converter) external onlyOwner {
        require(_converter != address(0));
        stakingConverter = _converter;
    }

    function setRoyalties(address _royal) external onlyOwner {
        require(_royal != address(0));
        royalties = _royal;
    }

    function setSplitter(address _splitter, bool _what) external onlyOwner {
        splitter[_splitter] = _what;
    }

    
    ///@notice in case token get stuck.
    function withdrawERC20(address _token) external onlyOwner {
        require(_token != address(0));
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(msg.sender, _balance);
    }

    function setFees(uint256 _amountToStaking, uint256 _amountToRoyalties ) external onlyOwner {
        require(converterFee + royaltiesFee <= PRECISION, 'too many');
        converterFee = _amountToStaking;
        royaltiesFee = _amountToRoyalties;
    }

    receive() external payable {}

}