# Clout Deployments

## Base Sepolia Testnet (chain ID 84532)

| Contract       | Address                                      | Explorer |
|----------------|----------------------------------------------|----------|
| MockStablecoin | `0xCF31F10B6be540c08060253334B1ad99b2C8E488` | [Basescan](https://sepolia.basescan.org/address/0xCF31F10B6be540c08060253334B1ad99b2C8E488) |
| CloutEscrow    | `0x7D7F328a9eFDc4d6a332892a0902b549f2cB7E8D` | [Basescan](https://sepolia.basescan.org/address/0x7D7F328a9eFDc4d6a332892a0902b549f2cB7E8D) |
| CloutPool      | `0x25d7c79044Ef8d0C7978822086d2d4D4b7C2bb65` | [Basescan](https://sepolia.basescan.org/address/0x25d7c79044Ef8d0C7978822086d2d4D4b7C2bb65) |

## Configuration

| Parameter      | Value |
|----------------|-------|
| Owner          | `0x265bDa014C4A7AF0a1AC2e01978f25E0e20cBb32` |
| Treasury       | `0x265bDa014C4A7AF0a1AC2e01978f25E0e20cBb32` |
| Fee (bps)      | 250 (2.5%) |
| Chain          | Base Sepolia (84532) |

## How to update
After running `forge script script/Deploy.s.sol --broadcast --rpc-url $BASE_SEPOLIA_RPC_URL`,
fill in fields above with addresses from the broadcast output.
