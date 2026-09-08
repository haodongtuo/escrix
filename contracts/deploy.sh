#!/bin/bash
# Deploy EscrixEscrow to Base Sepolia testnet
# Usage: PRIVATE_KEY=0x... TREASURY=0x... bash deploy.sh

set -e

PRIVATE_KEY=${PRIVATE_KEY:?Need PRIVATE_KEY}
TREASURY=${TREASURY:?Need TREASURY address}
RPC="https://sepolia.base.org"

echo "🚀 Deploying EscrixEscrow to Base Sepolia..."
echo "   Treasury: $TREASURY"

forge create \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY" \
  --constructor-args "$TREASURY" \
  --verify \
  src/EscrixEscrow.sol:EscrixEscrow

echo "✅ Deployment complete. Update api/index.js with the contract address."
