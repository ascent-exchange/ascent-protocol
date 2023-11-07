
// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../interfaces/IBribeAPI.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IPair.sol';
import '../interfaces/IPairFactory.sol';
import '../interfaces/IGaugeFactory.sol';
import '../interfaces/IVoter.sol';
import '../interfaces/IVotingEscrow.sol';
import '../interfaces/IRewardsDistributor.sol';

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract veNFTAPI is Initializable {

    struct pairVotes {
        address pair;
        uint256 weight;
    }

    struct veNFT {        
        bool voted;
        uint256 id;
        uint128 amount;
        uint256 voting_amount;
        uint256 rebase_amount;
        uint256 lockEnd;
        uint256 vote_ts;
        pairVotes[] votes;        
        address account;
    }

    struct Reward {
        uint256 id;
        uint256 amount;

        address pair;
        string pair_symbol;
        uint reserve0;
        uint reserve1;
        uint total_supply;
        address token0;
        uint token0_decimals;
        string token0_symbol;
        address token1;
        uint token1_decimals;
        string token1_symbol;

        address token;
        uint8 decimals;
        string symbol;

        address fee;
        address bribe;
    }

    uint256 constant public MAX_RESULTS = 1000;
    uint256 constant public MAX_PAIRS = 30;

    IVoter public voter;
    address public underlyingToken;
    

    IVotingEscrow public ve;
    IRewardsDistributor public rewardDisitributor;

    IPairFactory public pairFactory;
    

    address public owner;
    event Owner(address oldOwner, address newOwner);

    struct AllPairRewards {
        Reward[] rewards;
    }
    constructor() {}

    function initialize(address _voter, address _rewarddistro) initializer public {

        owner = msg.sender;

        voter = IVoter(_voter);
        rewardDisitributor = IRewardsDistributor(_rewarddistro);

        require(rewardDisitributor.voting_escrow() == voter._ve(), 've!=ve');
        
        ve = IVotingEscrow( rewardDisitributor.voting_escrow() );
        underlyingToken = IVotingEscrow(ve).token();

        pairFactory = IPairFactory(voter.factory());
    }


    function getAllNFT(uint256 _amounts, uint256 _offset) external view returns(veNFT[] memory _veNFT){

        require(_amounts <= MAX_RESULTS, 'too many nfts');
        _veNFT = new veNFT[](_amounts);

        uint i = _offset;
        address _owner;

        for(i; i < _offset + _amounts; i++){
            _owner = ve.ownerOf(i);
            // if id_i has owner read data
            if(_owner != address(0)){
                _veNFT[i-_offset] = _getNFTFromId(i, _owner);
            }
        }
    }

    function getNFTFromId(uint256 id) external view returns(veNFT memory){
        return _getNFTFromId(id,ve.ownerOf(id));
    }

    function getNFTFromAddress(address _user) external view returns(veNFT[] memory venft){

        uint256 i=0;
        uint256 _id;
        uint256 totNFTs = ve.balanceOf(_user);

        venft = new veNFT[](totNFTs);

        for(i; i < totNFTs; i++){
            _id = ve.tokenOfOwnerByIndex(_user, i);
            if(_id != 0){
                venft[i] = _getNFTFromId(_id, _user);
            }
        }
    }

    function _getNFTFromId(uint256 id, address _owner) internal view returns(veNFT memory venft){

        if(_owner == address(0)){
            return venft;
        }

        uint _totalPoolVotes = voter.poolVoteLength(id);
        pairVotes[] memory votes = new pairVotes[](_totalPoolVotes);

        IVotingEscrow.LockedBalance memory _lockedBalance;
        _lockedBalance = ve.locked(id);

        uint k;
        uint256 _poolWeight;
        address _votedPair;

        for(k = 0; k < _totalPoolVotes; k++){

            _votedPair = voter.poolVote(id, k);
            if(_votedPair == address(0)){
                break;
            }
            _poolWeight = voter.votes(id, _votedPair);
            votes[k].pair = _votedPair;
            votes[k].weight = _poolWeight;
        }

        venft.id = id;
        venft.account = _owner;
        venft.amount = uint128(_lockedBalance.amount);
        venft.voting_amount = ve.balanceOfNFT(id);
        venft.rebase_amount = rewardDisitributor.claimable(id);
        venft.lockEnd = _lockedBalance.end;
        venft.vote_ts = voter.lastVoted(id);
        venft.votes = votes;
        venft.voted = ve.voted(id);      
    }

    // used only for sAMM and vAMM    
    function allPairRewards(uint256 _amount, uint256 _offset, uint256 id) external view returns(AllPairRewards[] memory rewards){
        
        rewards = new AllPairRewards[](MAX_PAIRS);

        uint256 totalPairs = pairFactory.allPairsLength();
        
        uint i = _offset;
        address _pair;
        for(i; i < _offset + _amount; i++){
            if(i >= totalPairs){
                break;
            }
            _pair = pairFactory.allPairs(i);
            rewards[i].rewards = _pairReward(_pair, id);
        }
    }

    function allPairRewardsFromGauges(uint256 _amount, uint256 _offset, uint256 id) external view returns(AllPairRewards[] memory rewards, uint256 total){
        IGaugeFactory gaugeFactory = IGaugeFactory(voter.gaugefactory());
        address[] memory _gauges = gaugeFactory.gauges();
        total = _gauges.length;

        if (_offset >= _gauges.length) {
            return (rewards, total);
        }

        rewards = new AllPairRewards[](total > _offset + _amount ? _amount : total - _offset);

        for(uint i = _offset; i < _offset + _amount; i++){
            if(i >= total){
                break;
            }
            address _pair = voter.poolForGauge(_gauges[i]);
            rewards[i - _offset].rewards = _pairReward(_pair, id);
        }
    }

    function singlePairReward(uint256 id, address _pair) external view returns(Reward[] memory _reward){
        return _pairReward(_pair, id);
    }


    function _pairReward(address _pair, uint256 id) internal view returns(Reward[] memory _reward){

        if(_pair == address(0)){
            return _reward;
        }

        if(voter.gauges(_pair) == address(0)){
            return _reward;
        }

        address externalBribe = voter.external_bribes(address(voter.gauges(_pair)));
        address internalBribe = voter.internal_bribes(address(voter.gauges(_pair)));

        uint256 totBribeTokens = (externalBribe == address(0)) ? 0 : IBribeAPI(externalBribe).rewardsListLength();

        uint bribeAmount;
        _reward = new Reward[](2 + totBribeTokens);

        IPair ipair = IPair(_pair);
        address[] memory t = new address[](2);
        t[0] = ipair.token0();
        t[1] = ipair.token1();
        uint256 _feeToken0 = IBribeAPI(internalBribe).earned(id, t[0]);
        uint256 _feeToken1 = IBribeAPI(internalBribe).earned(id, t[1]);
        uint256[] memory reserves = new uint256[](2);
        (reserves[0], reserves[1],) = ipair.getReserves();


        if(_feeToken0 > 0){
            _reward[0] = Reward({
                id: id,
                pair: _pair,
                pair_symbol: ipair.symbol(),
                reserve0: reserves[0],
                reserve1: reserves[1],
                total_supply: ipair.totalSupply(),
                token0: t[0],
                token0_symbol: IERC20(t[0]).symbol(),
                token0_decimals: IERC20(t[0]).decimals(),
                token1: t[1],
                token1_symbol: IERC20(t[1]).symbol(),
                token1_decimals: IERC20(t[1]).decimals(),
                amount: _feeToken0,
                token: t[0],
                symbol: IERC20(t[0]).symbol(),
                decimals: IERC20(t[0]).decimals(),
                fee: internalBribe,
                bribe: address(0)
            });
        }

        
        if(_feeToken1 > 0){
            _reward[1] = Reward({
                id: id,
                pair: _pair,
                pair_symbol: ipair.symbol(),
                reserve0: reserves[0],
                reserve1: reserves[1],
                total_supply: ipair.totalSupply(),
                token0: t[0],
                token0_symbol: IERC20(t[0]).symbol(),
                token0_decimals: IERC20(t[0]).decimals(),
                token1: t[1],
                token1_symbol: IERC20(t[1]).symbol(),
                token1_decimals: IERC20(t[1]).decimals(),
                amount: _feeToken1,
                token: t[1],
                symbol: IERC20(t[1]).symbol(),
                decimals: IERC20(t[1]).decimals(),
                fee: internalBribe,
                bribe: address(0)
            });
        }


        //externalBribe point to Bribes.sol
        if(externalBribe == address(0)){
            return _reward;
        }

        uint k = 0;
        address _token;      

        for(k; k < totBribeTokens; k++){
            _token = IBribeAPI(externalBribe).rewardTokens(k);
            bribeAmount = IBribeAPI(externalBribe).earned(id, _token);

            _reward[2 + k] = Reward({
                id: id,
                pair: _pair,
                pair_symbol: ipair.symbol(),
                reserve0: reserves[0],
                reserve1: reserves[1],
                total_supply: ipair.totalSupply(),
                token0: t[0],
                token0_symbol: IERC20(t[0]).symbol(),
                token0_decimals: IERC20(t[0]).decimals(),
                token1: t[1],
                token1_symbol: IERC20(t[1]).symbol(),
                token1_decimals: IERC20(t[1]).decimals(),
                amount: bribeAmount,
                token: _token,
                symbol: IERC20(_token).symbol(),
                decimals: IERC20(_token).decimals(),
                fee: address(0),
                bribe: externalBribe
            });
        }

        return _reward;
    }


    function setOwner(address _owner) external {
        require(msg.sender == owner, 'not owner');
        require(_owner != address(0), 'zeroAddr');
        owner = _owner;
        emit Owner(msg.sender, _owner);
    }

  
    function setVoter(address _voter) external  {
        require(msg.sender == owner);

        voter = IVoter(_voter);
    }


    function setRewardDistro(address _rewarddistro) external {
        require(msg.sender == owner);
        
        rewardDisitributor = IRewardsDistributor(_rewarddistro);
        require(rewardDisitributor.voting_escrow() == voter._ve(), 've!=ve');

        ve = IVotingEscrow( rewardDisitributor.voting_escrow() );
        underlyingToken = IVotingEscrow(ve).token();
    }


    function setPairFactory(address _pairFactory) external {
        require(msg.sender == owner);  
        pairFactory = IPairFactory(_pairFactory);
    }
}
