# Mini-DON: Fault-Tolerant Oracle Node & Attack Testbed

[![Foundry](https://img.shields.io/badge/Foundry-Passing-brightgreen)](https://getfoundry.sh/)
[![Go](https://img.shields.io/badge/Go-1.22+-blue)](https://go.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A minimal viable implementation of a **Chainlink Decentralized Oracle Network (DON)** node and an EVM-native attack test harness. This project models concurrent multi-source price ingestion, Byzantine outlier filtering, and cryptographic verification on-chain, paired with Foundry-based exploit PoCs.

---

## Architecture Overview

```text
[Exchange REST APIs (Binance / Coinbase / Kraken)]
                      â”‚
                      â•¼ (Goroutines + sync.WaitGroup + context.Timeout)
[Go Oracle Core Node]
      â””â€” Fault Tolerance: Fallback & graceful degradation on timeouts
      â”œâ€” Outlier Filter: Median aggregation with Â±5 deviation pruning
      â””â€” Cryptographic Packaging: EIP-191 Secp256k1 signing (v, r, s)
                      â”‚
                      â•¼ (JSON-RPC)
[MiniOracle.sol (Consumer Contract)]
      â”œâ€” Replay Defense: EIP-155 chainID + contract address isolation
      â‘¥8 %œ™\Ú™\ÜÈÝX\™ˆ[Y\Ý[\[Û›ÝÛšXÈ[˜Ü™X\ÙH	ˆÌÈX^Ý[[™\ÜÂˆ8¤iN(	BæF—fR&V6÷fW'“¢–æÆ–æR76VÖ&Ç’V7&V6÷fW&fÆ–FF–öà¢)H ¢)[À¥´f÷VæG'’GF6²FW7F&VEÐ¢)SŠPA½€Äè±…Í 1½…¸`5…¹¥ÁÕ±…Ñ¥½¸•™•¹Í”(€€€€€ƒŠF”â€” PoC 2: Byzantine Price Outlier Property-Based Fuzzing (256 runs)
      â”œâ€” Test 3: Unauthorized Signature Reversion
      â””â€” Test 4: Historical Timestamp Replay Prevention
```

---

## Quick Start

- [Foundry](https://getfoundry.sh/)
- Go (>= 1.21)

### Execution
Run the full verification harness:
```bash
./test_e2e.sh
```
