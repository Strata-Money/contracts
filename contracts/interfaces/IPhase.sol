// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

enum PreDepositPhase {
    PointsPhase,
    YieldPhase
}

interface IPreDepositPhaser {
    function currentPhase() external view returns (PreDepositPhase);
}
