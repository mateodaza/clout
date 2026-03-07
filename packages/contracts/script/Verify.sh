#!/usr/bin/env bash
set -e

# ---------------------------------------------------------------------------
# Verify.sh — Verify Clout contracts on Basescan (Base Sepolia)
#
# Usage:
#   # Using env vars
#   MOCK_STABLECOIN_ADDRESS=0x... CLOUT_ESCROW_ADDRESS=0x... CLOUT_POOL_ADDRESS=0x... ./script/Verify.sh
#
#   # Using positional args (override env vars)
#   ./script/Verify.sh 0x<mock> 0x<escrow> 0x<pool>
#
# Required env var:
#   BASESCAN_API_KEY — get yours at https://basescan.org/myapikey
# ---------------------------------------------------------------------------

MOCK_STABLECOIN="${1:-$MOCK_STABLECOIN_ADDRESS}"
CLOUT_ESCROW="${2:-$CLOUT_ESCROW_ADDRESS}"
CLOUT_POOL="${3:-$CLOUT_POOL_ADDRESS}"

if [ -z "$BASESCAN_API_KEY" ]; then
  echo "Error: BASESCAN_API_KEY is not set."
  echo ""
  echo "Usage:"
  echo "  BASESCAN_API_KEY=<key> MOCK_STABLECOIN_ADDRESS=0x... CLOUT_ESCROW_ADDRESS=0x... CLOUT_POOL_ADDRESS=0x... ./script/Verify.sh"
  echo "  BASESCAN_API_KEY=<key> ./script/Verify.sh 0x<mock> 0x<escrow> 0x<pool>"
  echo ""
  echo "Get your API key at: https://basescan.org/myapikey"
  exit 1
fi

if [ -z "$MOCK_STABLECOIN" ] || [ -z "$CLOUT_ESCROW" ] || [ -z "$CLOUT_POOL" ]; then
  echo "Error: All three contract addresses must be provided."
  echo ""
  echo "Provide them as positional args or env vars:"
  echo "  MOCK_STABLECOIN_ADDRESS, CLOUT_ESCROW_ADDRESS, CLOUT_POOL_ADDRESS"
  exit 1
fi

COMMON_FLAGS=(
  --chain base-sepolia
  --verifier etherscan
  --etherscan-api-key "$BASESCAN_API_KEY"
  --compiler-version 0.8.20
  --num-of-optimizations 200
  --via-ir
  --watch
)

echo "Verifying MockStablecoin at $MOCK_STABLECOIN ..."
forge verify-contract \
  "$MOCK_STABLECOIN" \
  src/MockStablecoin.sol:MockStablecoin \
  "${COMMON_FLAGS[@]}"

echo "Verifying CloutEscrow at $CLOUT_ESCROW ..."
forge verify-contract \
  "$CLOUT_ESCROW" \
  src/CloutEscrow.sol:CloutEscrow \
  "${COMMON_FLAGS[@]}"

echo "Verifying CloutPool at $CLOUT_POOL ..."
forge verify-contract \
  "$CLOUT_POOL" \
  src/CloutPool.sol:CloutPool \
  "${COMMON_FLAGS[@]}"

echo "All contracts verified successfully."
