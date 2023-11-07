// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import '../interfaces/IGaugeFactoryV2.sol';
import '../GaugeV2.sol';
import "../CLFeesVault.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract GaugeFactoryV2 is IGaugeFactory, OwnableUpgradeable {
    address public last_gauge;
    address public last_feeVault;
    address public gammaFeeRecipient;
    address public pairFactory;

    address[] internal __gauges;

    constructor() {}

    function initialize(address _pairFactory) initializer  public {
        __Ownable_init();
        pairFactory = _pairFactory;
    }

    function gauges() external view returns(address[] memory) {
        return __gauges;
    }

    function length() external view returns(uint) {
        return __gauges.length;
    }

    function createGaugeV2(address _rewardToken,address _ve,address _token,address _distribution, address _internal_bribe, address _external_bribe, bool _isPair, bool _isCL) external returns (address) {
        last_feeVault = _isCL ? address(new CLFeesVault(owner(), _token, pairFactory, _distribution, gammaFeeRecipient)) : address(0);
        last_gauge = address(new GaugeV2(_rewardToken,_ve,_token,_distribution,_internal_bribe,_external_bribe,_isPair,_isCL,last_feeVault) );
        __gauges.push(last_gauge);

        return last_gauge;
    }

    function setDistribution(address _gauge, address _newDistribution) external onlyOwner {
        IGauge(_gauge).setDistribution(_newDistribution);
    }

    function setRewarderPid( address[] memory _gauges, uint[] memory _pids) external onlyOwner {
        require(_gauges.length == _pids.length);
        uint i = 0;
        for ( i ; i < _gauges.length; i++){
            IGauge(_gauges[i]).setRewarderPid(_pids[i]);
        }
    }

    function setGaugeRewarder( address[] memory _gauges, address[] memory _rewarder) external onlyOwner {
        require(_gauges.length == _rewarder.length);
        uint i = 0;
        for ( i ; i < _gauges.length; i++){
            IGauge(_gauges[i]).setGaugeRewarder(_rewarder[i]);
        }
    }

    function setGaugeFeeVault(address[] memory _gauges,  address _vault) external onlyOwner {
        require(_vault != address(0));
        uint i = 0;
        for ( i ; i < _gauges.length; i++){
            require(_gauges[i] != address(0));
            IGauge(_gauges[i]).setFeeVault(_vault);
        }
    }

    function setPairFactory(address _factory) external onlyOwner {
        require(_factory != address(0));
        pairFactory = _factory;
    }

    function setGammaDefaultFeeRecipient(address _rec) external onlyOwner {
        require(_rec != address(0));
        gammaFeeRecipient = _rec;
    }
}
