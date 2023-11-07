// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../interfaces/IBribeAPI.sol';
import '../interfaces/IGaugeAPI.sol';
import '../interfaces/IGaugeFactory.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IPair.sol';
import '../interfaces/IPairFactory.sol';
import '../interfaces/IVoter.sol';
import '../interfaces/IVotingEscrow.sol';

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract PairAPI is Initializable {

    struct PairInfo {
        // pair info
        address pair_address; 			// pair contract address
        string symbol; 				    // pair symbol
        string name;                    // pair name
        uint decimals; 			        // pair decimals
        bool stable; 				    // pair pool type (stable = false, means it's a variable type of pool)
        uint total_supply; 			    // pair tokens supply
        uint weight;                    // pool weight
    
        // token pair info
        address token0; 				// pair 1st token address
        string token0_symbol; 			// pair 1st token symbol
        uint token0_decimals; 		    // pair 1st token decimals
        uint reserve0; 			        // pair 1st token reserves (nr. of tokens in the contract)
        uint claimable0;                // claimable 1st token from fees (for unstaked positions)

        address token1; 				// pair 2nd token address
        string token1_symbol;           // pair 2nd token symbol
        uint token1_decimals;    		// pair 2nd token decimals
        uint reserve1; 			        // pair 2nd token reserves (nr. of tokens in the contract)
        uint claimable1; 			    // claimable 2nd token from fees (for unstaked positions)

        address gauge;                  // gauge address

        // User deposit
        uint account_lp_balance; 		// account LP tokens balance
        uint account_token0_balance; 	// account 1st token balance
        uint account_token1_balance; 	// account 2nd token balance
    }

    struct RewardToken {
        address token;
        string symbol;
        uint decimals;
        uint left;
    }

    struct GaugeInfo {
        address gauge; 				      // pair gauge address
        uint gauge_total_supply; 		  // pair staked tokens (less/eq than/to pair total supply)
        uint emissions; 			      // pair emissions (per second)
        address fee; 				      // pair fees contract address
        address bribe; 				      // pair bribes contract address
        RewardToken[] feeRewardTokens;    // fee reward tokens
        RewardToken[] bribeRewardTokens;  // bribe reward tokens

        uint account_gauge_balance;       // account pair staked in gauge balance
        uint account_gauge_earned; 		  // account earned emissions for this pair
    }

    struct PairGaugeInfo {
        PairInfo pairInfo;
        GaugeInfo gaugeInfo;
    }

    struct BasePairInfo {
        // pair info
        address pair_address; 			// pair contract address
        string symbol; 				    // pair symbol
        string name;                    // pair name
        uint decimals; 			        // pair decimals
        uint total_supply; 			    // pair tokens supply
    
        // token pair info
        address token0; 				// pair 1st token address
        string token0_symbol; 			// pair 1st token symbol
        uint token0_decimals; 		    // pair 1st token decimals
        uint reserve0; 			        // pair 1st token reserves (nr. of tokens in the contract)

        address token1; 				// pair 2nd token address
        string token1_symbol;           // pair 2nd token symbol
        uint token1_decimals;    		// pair 2nd token decimals
        uint reserve1; 			        // pair 2nd token reserves (nr. of tokens in the contract)
    }

    uint256 public constant MAX_PAIRS = 1000;

    IPairFactory public pairFactory;
    IVoter public voter;

    address public underlyingToken;

    address public owner;


    event Owner(address oldOwner, address newOwner);
    event Voter(address oldVoter, address newVoter);

    constructor() {}

    function initialize(address _voter) initializer public {
  
        owner = msg.sender;

        voter = IVoter(_voter);

        pairFactory = IPairFactory(voter.factory());
        underlyingToken = IVotingEscrow(voter._ve()).token();        
    }


    // valid only for sAMM and vAMM
    function getAllPair(address _user, uint _amounts, uint _offset) external view returns(PairInfo[] memory Pairs, uint total){
        total = pairFactory.allPairsLength();
        address _pair;

        if (_offset >= total) {
            return (Pairs, total);
        }

        Pairs = new PairInfo[](total > _offset + _amounts ? _amounts : total - _offset);

        for(uint i = _offset; i < _offset + _amounts; i++){
            // if totalPairs is reached, break.
            if(i >= total) {
                break;
            }
            _pair = pairFactory.allPairs(i);
            Pairs[i - _offset] = _getPairInfo(_pair, _user);
        }
    }

    function getAllGauge(address _user, uint _amount, uint _offset) external view returns(PairGaugeInfo[] memory info, uint total){
        IGaugeFactory gaugeFactory = IGaugeFactory(voter.gaugefactory());
        address[] memory _gauges = gaugeFactory.gauges();
        total = _gauges.length;

        if (_offset >= _gauges.length) {
            return (info, total);
        }

        info = new PairGaugeInfo[](total > _offset + _amount ? _amount : total - _offset);

        for(uint i = _offset; i < _offset + _amount; i++){
            if(i >= total){
                break;
            }
            address _pair = voter.poolForGauge(_gauges[i]);
            info[i - _offset] = _getPairGaugeInfo(_pair, _user);
        }
    }

    function getPair(address _pair, address _account) external view returns(PairInfo memory _pairInfo){
        return _getPairInfo(_pair, _account);
    }

    function getGauge(address _pair, address _account) external view returns(GaugeInfo memory _gaugeInfo){
        return _getGaugeInfo(_pair, _account);
    }

    function getPairGauge(address _pair, address _account) external view returns(PairGaugeInfo memory _gaugeInfo){
        return _getPairGaugeInfo(_pair, _account);
    }

    function getPairs(address[] calldata _pairs, address _account) external view returns(PairInfo[] memory _pairInfo){
        _pairInfo = new PairInfo[](_pairs.length);
        for (uint i = 0; i < _pairs.length; i++) {
            _pairInfo[i] = _getPairInfo(_pairs[i], _account);
        }
    }

    function getGauges(address[] calldata _pairs, address _account) external view returns(GaugeInfo[] memory _gaugeInfo){
        _gaugeInfo = new GaugeInfo[](_pairs.length);
        for (uint i = 0; i < _pairs.length; i++) {
            _gaugeInfo[i] = _getGaugeInfo(_pairs[i], _account);
        }
    }

    function getPairGauges(address[] calldata _pairs, address _account) external view returns(PairGaugeInfo[] memory _gaugeInfo){
        _gaugeInfo = new PairGaugeInfo[](_pairs.length);
        for (uint i = 0; i < _pairs.length; i++) {
            _gaugeInfo[i] = _getPairGaugeInfo(_pairs[i], _account);
        }
    }

    function getBasePairs(address[] calldata _pairs) external view returns(BasePairInfo[] memory _pairInfo){
        _pairInfo = new BasePairInfo[](_pairs.length);
        for (uint i = 0; i < _pairs.length; i++) {
            _pairInfo[i] = _getBasePairInfo(_pairs[i]);
        }
    }

    function _getPairInfo(address _pair, address _account) internal view returns(PairInfo memory _pairInfo) {
        IPair ipair = IPair(_pair);

        address token_0 = ipair.token0();
        address token_1 = ipair.token1();
        uint r0;
        uint r1;

        (r0,r1,) = ipair.getReserves();

        // Pair General Info
        _pairInfo.pair_address = _pair;
        _pairInfo.symbol = ipair.symbol();
        _pairInfo.name = ipair.name();
        _pairInfo.decimals = ipair.decimals();
        _pairInfo.stable = ipair.isStable();
        _pairInfo.total_supply = ipair.totalSupply();
        _pairInfo.weight = voter.weights(_pair);

        // Token0 Info
        _pairInfo.token0 = token_0;
        _pairInfo.token0_decimals = IERC20(token_0).decimals();
        _pairInfo.token0_symbol = IERC20(token_0).symbol();
        _pairInfo.reserve0 = r0;
        _pairInfo.claimable0 = ipair.claimable0(_account);

        // Token1 Info
        _pairInfo.token1 = token_1;
        _pairInfo.token1_decimals = IERC20(token_1).decimals();
        _pairInfo.token1_symbol = IERC20(token_1).symbol();
        _pairInfo.reserve1 = r1;
        _pairInfo.claimable1 = ipair.claimable1(_account);

        // Gauge address
        _pairInfo.gauge = voter.gauges(_pair);

        // Account Info
        _pairInfo.account_lp_balance = IERC20(_pair).balanceOf(_account);
        _pairInfo.account_token0_balance = IERC20(token_0).balanceOf(_account);
        _pairInfo.account_token1_balance = IERC20(token_1).balanceOf(_account);
    }

    function _getGaugeInfo(address _pair, address _account) internal view returns(GaugeInfo memory _gaugeInfo) {
        IGaugeAPI _gauge = IGaugeAPI(voter.gauges(_pair));
        uint gaugeTotalSupply = 0;
        uint emissions = 0;
        address[] memory bribes = new address[](2);
        RewardToken[] memory feeRewardTokens =  new RewardToken[](0);
        RewardToken[] memory bribeRewardTokens =  new RewardToken[](0);

        uint accountGaugeLPAmount = 0;
        uint earned = 0;

        if(address(_gauge) != address(0)){
            gaugeTotalSupply = _gauge.totalSupply();
            emissions = _gauge.rewardRate();
            bribes[0] = voter.internal_bribes(address(_gauge));
            bribes[1] = voter.external_bribes(address(_gauge));

            uint k = 0;
            address _token;
            uint nextEpochStart = IBribeAPI(bribes[0]).getNextEpochStart();

            feeRewardTokens =  new RewardToken[](2);
            for(k; k < 2; k++){
                _token = IBribeAPI(bribes[0]).rewardTokens(k);

                feeRewardTokens[k] = RewardToken({
                    token: _token,
                    symbol: IERC20(_token).symbol(),
                    decimals: IERC20(_token).decimals(),
                    left: IBribeAPI(bribes[0]).rewardData(_token, nextEpochStart).rewardsPerEpoch
                });
            }

            uint length = IBribeAPI(bribes[1]).rewardsListLength();
            bribeRewardTokens =  new RewardToken[](length);
            for(k = 0; k < length; k++){
                _token = IBribeAPI(bribes[1]).rewardTokens(k);

                bribeRewardTokens[k] = RewardToken({
                    token: _token,
                    symbol: IERC20(_token).symbol(),
                    decimals: IERC20(_token).decimals(),
                    left: IBribeAPI(bribes[1]).rewardData(_token, nextEpochStart).rewardsPerEpoch
                });
            }

            if(_account != address(0)){
                accountGaugeLPAmount = _gauge.balanceOf(_account);
                earned = _gauge.earned(_account);
            } else {
                accountGaugeLPAmount = 0;
                earned = 0;
            }
        }

        _gaugeInfo = GaugeInfo(
            address(_gauge),
            gaugeTotalSupply,
            emissions,
            bribes[0],
            bribes[1],
            feeRewardTokens,
            bribeRewardTokens,
            accountGaugeLPAmount,
            earned
        );
    }

    function _getPairGaugeInfo(address _pair, address _account) internal view returns(PairGaugeInfo memory _pairGaugeInfo){
        _pairGaugeInfo.pairInfo = _getPairInfo(_pair, _account);
        _pairGaugeInfo.gaugeInfo = _getGaugeInfo(_pair, _account);
    }

    function _getBasePairInfo(address _pair) internal view returns(BasePairInfo memory _pairInfo) {
        IPair ipair = IPair(_pair);

        address token_0 = ipair.token0();
        address token_1 = ipair.token1();
        uint r0;
        uint r1;

        (r0,r1,) = ipair.getReserves();

        // Pair General Info
        _pairInfo.pair_address = _pair;
        _pairInfo.symbol = ipair.symbol();
        _pairInfo.name = ipair.name();
        _pairInfo.decimals = ipair.decimals();
        _pairInfo.total_supply = ipair.totalSupply();        

        // Token0 Info
        _pairInfo.token0 = token_0;
        _pairInfo.token0_decimals = IERC20(token_0).decimals();
        _pairInfo.token0_symbol = IERC20(token_0).symbol();
        _pairInfo.reserve0 = r0;

        // Token1 Info
        _pairInfo.token1 = token_1;
        _pairInfo.token1_decimals = IERC20(token_1).decimals();
        _pairInfo.token1_symbol = IERC20(token_1).symbol();
        _pairInfo.reserve1 = r1;
    }


    function setOwner(address _owner) external {
        require(msg.sender == owner, 'not owner');
        require(_owner != address(0), 'zeroAddr');
        owner = _owner;
        emit Owner(msg.sender, _owner);
    }


    function setVoter(address _voter) external {
        require(msg.sender == owner, 'not owner');
        require(_voter != address(0), 'zeroAddr');
        address _oldVoter = address(voter);
        voter = IVoter(_voter);
        
        // update variable depending on voter
        pairFactory = IPairFactory(voter.factory());
        underlyingToken = IVotingEscrow(voter._ve()).token();

        emit Voter(_oldVoter, _voter);
    }

    function left(address _pair, address _token) external view returns(uint256 _rewPerEpoch){
        address _gauge = voter.gauges(_pair);
        IBribeAPI bribe  = IBribeAPI(voter.internal_bribes(_gauge));
        
        uint256 _ts = bribe.getEpochStart();
        IBribeAPI.Reward memory _reward = bribe.rewardData(_token, _ts);
        _rewPerEpoch = _reward.rewardsPerEpoch;
    
    }
}
