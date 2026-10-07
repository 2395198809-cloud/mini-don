#!/usr/bin/env bash
set -e

echo "=== 1. Running Foundry Smart Contract Test Suite ==="
cd contracts
forge test -vv
cd ..

echo -e "\n=== 2. Running Go Core Aggregator & Secp256k1 Signer ==="
cd node
go run main.go
cd ..

echo -e "\n=== E2E Test Pipeline Passed Successfully ==="
