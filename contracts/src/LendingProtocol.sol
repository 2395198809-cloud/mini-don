// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MiniOracle.sol";

interface ISpotDEX {
    function getSpotPrice() external view returns (uint256);
}

contract LendingProtocol {
    MiniOracle public immutable oracle;
    ISpotDEX public immutable spotDEX;
    
    uint256 public constant COLLATERAL_FACTOR = 75;
    uint256 public constant LIQUIDATION_THRESHOLD = 80;

    mapping(address => uint256) public userCollateral;
    mapping(address => uint256) public userDebt;

    error Undercollateralized();
    error HealthyPosition();

    constructor(address _oracle, address _spotDEX) {
        oracle = MiniOracle(_oracle);
        spotDEX = ISpotDEX(_spotDEX);
    }

    function depositCollateral() external payable {
        userCollateral[msg.sender] += msg.value;
    }

    function borrowVulnerable(uint256 borrowAmount) external {
        uint256 spotPrice = spotDEX.getSpotPrice();
        uint256 collateralValue = (userCollateral[msg.sender] * spotPrice) / 1e18;
        uint256 maxBorrow = (collateralValue * COLLATERAL_FACTOR) / 100;

        if (userDebt[msg.sender] + borrowAmount > maxBorrow) revert Undercollateralized();
        userDebt[msg.sender] += borrowAmount;
    }

    function borrowProtected(uint256 borrowAmount) external {
        uint256 oraclePrice = oracle.latestPrice();
        uint256 collateralValue = (userCollateral[msg.sender] * oraclePrice) / 1e18;
        uint256 maxBorrow = (collateralValue * COLLATERAL_FACTOR) / 100;

        if (userDebt[msg.sender] + borrowAmount > maxBorrow) revert Undercollateralized();
        userDebt[msg.sender] += borrowAmount;
    }

    function liquidateVulnerable(address borrower) external {
        uint256 spotPrice = spotDEX.getSpotPrice();
        uint256 collateralValue = (userCollateral[borrower] * spotPrice) / 1e18;
        uint256 maxAllowedDebt = (collateralValue * LIQUIDATION_THRESHOLD) / 100;

        if (userDebt[borrower] <= maxAllowedDebt) revert HealthyPosition();
        userCollateral[borrower] = 0;
        userDebt[borrower] = 0;
    }

    function liquidateProtected(address borrower) external {
        uint256 oraclePrice = oracle.latestPrice();
        uint256 collateralValue = (userCollateral[borrower] * oraclePrice) / 1e18;
        uint256 maxAllowedDebt = (collateralValue * LIQUIDATION_THRESHOLD) / 100;

        if (userDebt[borrower] <= maxAllowedDebt) revert HealthyPosition();
        userCollateral[borrower] = 0;
        userDebt[borrower] = 0;
    }
}
