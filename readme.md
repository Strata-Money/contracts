# Strata contracts


[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/CuZPw4nX5nC1pEn3Ea9opp/Fc4365omRPYr1x82FJDJvp/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/circleci/CuZPw4nX5nC1pEn3Ea9opp/Fc4365omRPYr1x82FJDJvp/tree/master)



Introduction
----------

Strata is a perpetual yield tranching protocol built on the Ethena Network, designed to offer structured yield exposure on USDe, Ethena’s delta-neutral synthetic stablecoin. Strata allows investors to optimize their risk-return preferences while earning yield from Ethena’s carry trade strategies with two risk-adjusted investment profiles—Senior and Junior.

Docs
----------

[docs.strata.money](https://strata-finance.gitbook.io/docs)


Deployment + Verification
----------

```bash

# Testnet Ethena dependencies
npx hardhat ignition deploy ignition/modules/Testnet.ts --network hoodi --verify

# Predeposit
npx hardhat ignition deploy ignition/modules/pUSDePreDepositModule.ts --network hoodi --verify



```

Tests
----------

To run tests first spin up a ganache-cli instance with unlimited contract size flag
```
npm run test
```

Deployments
-----------

### Hoodi

- `MockUSDe`: [0x7054A803361640970176Edbd91992DcC52B7D235](https://hoodi.etherscan.io/address/0x7054A803361640970176Edbd91992DcC52B7D235)
- `MockStakedUSDe`: [0x789d3D9AA2EFDda01f0402a632803158F21cCe05](https://hoodi.etherscan.io/address/0x789d3D9AA2EFDda01f0402a632803158F21cCe05)
- `PreDepositVault`: [0xaBE28B44a8bD32a0df6Ae784a5F5Ff0a03a57e98](https://hoodi.etherscan.io/address/0xaBE28B44a8bD32a0df6Ae784a5F5Ff0a03a57e98)

---


### Foundry Test

Tests can be found in `test/*.t.sol`

```bash
forge test
```

---
