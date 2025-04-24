// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.28;

interface IResilientOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface IOracleAggregatorV3 {
    function decimals() external view returns (uint8);
    function getRoundData(
        uint80 _roundId
    ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
