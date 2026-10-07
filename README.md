# Mini-DON: Fault-Tolerant Oracle Node & Attack Testbed

[![Foundry](https://img.shields.io/badge/Foundry-Passing-brightgreen)](https://getfoundry.sh/)
[![Go](https://img.shields.io/badge/Go-1.22-blue)](https://go.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A minimal viable implementation of a Chainlink Decentralized Oracle Network (DON) node and an EVM-native attack test harness.

## Architecture Overview

```
[Exchange REST APIs] --> (Goroutines + context.Timeout)
          |
          v
[Go Oracle Core Node]
  |-- Fault Tolerance: Fallback & graceful degradation
  |-- Outlier Filter: Median aggregation with 5% deviation pruning
  +-- Cryptographic Packaging: EIP-191 Secp256k1 signing
          |
          v
[MiniOracle.sol (Consumer Contract)]
  |-- Replay Defense: EIP-155 chainID + contract address isolation
  |-- Freshness Guard: Monotonic timestamp increase
  +-- Native Recovery: Inline assembly ecrecover validation
          |
          v
[Foundry Attack Testbed]
  |-- PoC 1: Flash Loan DEX Manipulation Defense
  |-- PoC 2: Byzantine Price Outlier Fuzzing (256 runs)
  |-- Test 3: Unauthorized Signature Reversion
  +-- Test 4: Historical Timestamp Replay Prevention
```

## Key Technical Highlights

1. Concurrent Ingestion & Timeout Degradation (2s context deadline).
2. Byzantine Fault Tolerance with 5% median outlier elimination.
3. Inline assembly ecrecover with EIP-155 domain binding against replay.
4. Proved lending pool immunity against single-block flash loan manipulation.

## Quick Start

```bash
./test_e2e.sh
```
