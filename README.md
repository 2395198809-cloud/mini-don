# Mini-DON: Fault-Tolerant Oracle Node & Attack Testbed

[![Foundry](https://img.shields.io/badge/Foundry-Passing-brightgreen)](https://getfoundry.sh/)
[![Go](https://img.shields.io/badge/Go-1.22-blue)](https://go.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A minimal viable implementation of a **Chainlink Decentralized Oracle Network (DON)** node and an EVM-native attack test harness. This project models concurrent multi-source price ingestion, Byzantine outlier filtering, and cryptographic verification on-chain, paired with Foundry-based exploit PoCs.

---

## Architecture Overview

```
[Exchange REST APIs (Binance / Coinbase / Kraken)]
                      |
                      +--> (Goroutines + sync.WaitGroup + context.Timeout)
[Go Oracle Core Node]
      |-- Fault Tolerance: Fallback & graceful degradation on timeouts
      |-- Outlier Filter: Median aggregation with 5% deviation pruning
      +-- Cryptographic Packaging: EIP-191 Secp256k1 signing (v, r, s)
                      |
                      +--> (JSON-RPC)
[MiniOracle.sol (Consumer Contract)]
      |-- Replay Defense: EIP-155 chainID + contract address isolation
      |-- Freshness Guard: Monotonic timestamp increase & 300s max staleness
      +-- Native Recovery: Inline assembly ecrecover validation
                      |
                      +--> (Foundry Attack Testbed)
                            |-- PoC 1-- Flash Loan DEX Manipulation Defense
                            |-- PoC 2-- Byzantine Price Outlier Property-Based Fuzzing (256 runs)
                            |-- Test 3-- Unauthorized Signature Reversion
                            +-- Test 4-- Historical Timestamp Replay Prevention
```

---

## Key Technical Highlights

1. **Concurrent Ingestion & Timeout Degradation**:
   - Fetches multiple external exchange endpoints concurrently using goroutines.
   - Guarded by strict 2s context deadlines, degrading gracefully to fallback feeds without blocking consensus.
2. **Byzantine Fault Tolerance & Outlier Elimination**:
   - Calculates median prices and prunes individual deviations exceeding 5%.
   - Validated via Foundry property-based fuzzing (256 runs) to ensure resilience against 100x price spikes.
3. **EVM-Native Cryptographic Verification**:
   - Enforces digest binding: keccak256(price, timestamp, chainId, address(this)).
   - Utilizes inline assembly ecrecover to eliminate cross-chain and cross-contract replay vulnerabilities.
4. **Flash Loan Manipulation PoC**:
   - Proves lending protocol immunity against single-block AMM liquidity skewing when using decentralized median pricing.

---

## Quick Start

- Foundry
- Go (>= 1.21)

### Run End-to-End Execution
```bash
./test_e2e.sh
```
