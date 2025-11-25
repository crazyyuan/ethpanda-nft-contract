# Memory of Ethereum NFT

[中文文档](./README_CN.md)

Memory of Ethereum - A commemorative NFT collection for each major Ethereum upgrade, built on the ERC-1155 standard with multi-token series management.

## 🎯 Project Overview

Memory of Ethereum is an innovative NFT project that releases a unique NFT series for each major Ethereum upgrade (such as Shapella, Dencun, Fusaka, etc.). Each series is an independent Token ID with its own configuration, whitelist, and pricing.

### Core Concepts

- 🌟 **Commemorative Significance**: Each NFT represents a major Ethereum technical upgrade
- 🎨 **Independent Series**: Each upgrade has its own Token ID and configuration
- 🔓 **Flexible Pricing**: Supports free or paid minting with different prices for different phases
- 🛡️ **Secure & Reliable**: Built on OpenZeppelin v5.1.0 and Foundry

## 🚀 Key Features

### Core Functionality

- ✅ **Multi-Token Support**: Create new Token ID for each Ethereum upgrade
- ✅ **Data Isolation**: Each token has independent configuration, whitelist, and user records
- ✅ **Flexible Pricing**: Support free/paid minting with different prices for whitelist and public phases
- ✅ **Automatic Refunds**: Excess ETH automatically refunded to users
- ✅ **Fund Management**: Admins can withdraw contract revenue

### Minting Mechanism

- 🎫 **Whitelist Phase**: Merkle Tree verification with gas optimization
- 🌍 **Public Phase**: Open to everyone
- 🎛️ **Manual Control**: Admins can start/end phases at any time
- 🔒 **Permanent End**: Can permanently disable minting for a token

### Permission Management

- 👥 **Multi-Admin**: Based on OpenZeppelin AccessControl
- 🔐 **Role Separation**: Two-level permissions (DEFAULT_ADMIN_ROLE and ADMIN_ROLE)
- ⚡ **Flexible Operations**: Support dynamic admin add/remove

## 📋 Tech Stack

- **Token Standard**: ERC-1155 (Multi-Token Standard)
- **Contract Library**: OpenZeppelin Contracts v5.1.0
- **Development Framework**: Foundry
- **Solidity Version**: ^0.8.24
- **Compilation**: via-ir mode
- **Whitelist**: Merkle Tree

## 🏗️ Project Structure

```
memory-of-ethereum-nft/
├── src/
│   └── EthereumOfMemoryNFT.sol         # Main contract (483 lines)
├── test/
│   └── EthereumOfMemoryNFT.t.sol       # Test suite (54 tests)
├── script/
│   ├── Deploy.s.sol                    # Deployment scripts (10+)
│   └── GenerateMerkleRoot.s.sol        # Merkle Root generator
├── scripts/
│   └── generateMerkleTree.js           # JavaScript Merkle Tree generator
├── metadata/
│   └── 1.json                          # NFT metadata example
├── lib/
│   ├── forge-std/                      # Foundry standard library
│   └── openzeppelin-contracts/         # OpenZeppelin v5.1.0
├── foundry.toml                        # Foundry configuration
└── package.json                        # Node.js dependencies
```

## 🛠️ Installation & Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v16+)
- [Git](https://git-scm.com/downloads)

### Install Dependencies

```bash
# Clone repository
git clone <repository-url>
cd memory-of-ethereum-nft

# Initialize git submodules
git submodule update --init --recursive

# Install Node.js dependencies
npm install
```

### Configure Environment Variables

Copy `.env.example` and fill in the configuration:

```bash
cp .env.example .env
```

Edit `.env` file:

```bash
# Private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# RPC endpoints
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID

# Etherscan API Key
ETHERSCAN_API_KEY=your_etherscan_api_key_here

# Default admin (optional)
DEFAULT_ADMIN=0xYourAdminAddress

# Token configuration
TOKEN_ID=1
UPGRADE_NAME=Shapella
MAX_SUPPLY=10000
WHITELIST_MAX_PER_ADDRESS=5
PUBLIC_MAX_PER_ADDRESS=1
WHITELIST_PRICE=0
PUBLIC_PRICE=0

# Fill after deployment
NFT_ADDRESS=0x...
MERKLE_ROOT=0x...
```

## 💻 Development

### Compile Contracts

```bash
npm run build
# or
forge build
```

### Run Tests

```bash
npm run test
# or
forge test --offline

# View gas report
forge test --gas-report

# View coverage
forge coverage
```

**Test Statistics**: 54 tests, 100% pass rate ✅

## 🚀 Deployment Process

### 1. Deploy Main Contract

```bash
npm run deploy:sepolia
```

This deploys the `EthereumOfMemoryNFT` contract and outputs the contract address.

### 2. Create First Token

Edit `.env` configuration:

```bash
NFT_ADDRESS=0xYourDeployedContractAddress
UPGRADE_NAME=Shapella
MAX_SUPPLY=10000
WHITELIST_MAX_PER_ADDRESS=5
PUBLIC_MAX_PER_ADDRESS=1
WHITELIST_PRICE=0                    # Free
PUBLIC_PRICE=0                       # Free
```

Execute creation:

```bash
forge script script/Deploy.s.sol:CreateTokenScript \
  --rpc-url sepolia \
  --broadcast
```

### 3. Generate Whitelist Merkle Tree

Create `whitelist.txt` file with one address per line:

```
0x1234567890123456789012345678901234567890
0xabcdefabcdefabcdefabcdefabcdefabcdefabcd
```

Generate Merkle Root:

```bash
npm run generate-merkle
```

### 4. Setup Whitelist

```bash
export TOKEN_ID=1
export MERKLE_ROOT=0x...  # From previous step

forge script script/Deploy.s.sol:SetupWhitelistScript \
  --rpc-url sepolia \
  --broadcast
```

### 5. Start Whitelist Phase

```bash
export TOKEN_ID=1
export WHITELIST_PRICE=0  # Or set price, e.g., 10000000000000000 (0.01 ETH)

forge script script/Deploy.s.sol:StartWhitelistPhaseScript \
  --rpc-url sepolia \
  --broadcast
```

### 6. Start Public Phase

```bash
export TOKEN_ID=1
export PUBLIC_PRICE=0  # Or set price

forge script script/Deploy.s.sol:StartPublicPhaseScript \
  --rpc-url sepolia \
  --broadcast
```

### 7. Withdraw Funds (if paid minting)

```bash
export WITHDRAW_TO=0xYourTreasuryAddress

forge script script/Deploy.s.sol:WithdrawScript \
  --rpc-url sepolia \
  --broadcast
```

## 📖 Contract Functions

### Token Management

#### Create New Token

Create a new token for each Ethereum upgrade:

```solidity
function createToken(
    string memory upgradeName,      // "Shapella", "Dencun", "Fusaka"
    uint256 maxSupply,              // 10000
    uint256 whitelistMaxPerAddress, // 5
    uint256 publicMaxPerAddress,    // 1
    uint256 whitelistPrice,         // 0 (free) or 0.01 ether
    uint256 publicPrice             // 0 (free) or 0.02 ether
) external returns (uint256 tokenId);
```

#### Update Token Configuration

```solidity
function updateTokenConfig(
    uint256 tokenId,
    uint256 maxSupply,
    uint256 whitelistMaxPerAddress,
    uint256 publicMaxPerAddress,
    uint256 whitelistPrice,
    uint256 publicPrice
) external;
```

#### Query Token Information

```solidity
function getTokenInfo(uint256 tokenId) external view returns (
    string memory upgradeName,
    uint256 maxSupply,
    uint256 currentSupply,
    uint256 whitelistMaxPerAddress,
    uint256 publicMaxPerAddress,
    uint256 whitelistPrice,
    uint256 publicPrice,
    MintPhase phase,
    bool ended
);
```

### User Minting

#### Whitelist Mint

```solidity
function whitelistMint(
    uint256 tokenId,
    uint256 amount,
    bytes32[] calldata merkleProof
) external payable;
```

Usage example:

```javascript
// Free mint
await nft.whitelistMint(1, 3, proof);

// Paid mint (0.01 ETH per NFT)
await nft.whitelistMint(1, 3, proof, { value: ethers.parseEther('0.03') });
```

#### Public Mint

```solidity
function publicMint(uint256 tokenId, uint256 amount) external payable;
```

Usage example:

```javascript
// Free mint
await nft.publicMint(1, 1);

// Paid mint
await nft.publicMint(1, 1, { value: ethers.parseEther('0.02') });
```

### Admin Functions

#### Admin Mint (Free)

```solidity
function adminMint(uint256 tokenId, address to, uint256 amount) external;
```

#### End Minting

```solidity
function endMintPermanently(uint256 tokenId) external;
```

#### Withdraw Funds

```solidity
function withdraw(address payable to) external;
```

#### Admin Management

```solidity
function addAdmin(address account) external;
function removeAdmin(address account) external;
function isAdmin(address account) external view returns (bool);
```

## 🎯 Usage Scenarios

### Scenario 1: Free Minting Campaign

```bash
# Create free token
export UPGRADE_NAME="Shapella"
export MAX_SUPPLY=10000
export WHITELIST_MAX_PER_ADDRESS=5
export PUBLIC_MAX_PER_ADDRESS=1
export WHITELIST_PRICE=0
export PUBLIC_PRICE=0

forge script script/Deploy.s.sol:CreateTokenScript --rpc-url sepolia --broadcast
```

### Scenario 2: Paid Minting Campaign

```bash
# Create paid token
export UPGRADE_NAME="Dencun"
export MAX_SUPPLY=8000
export WHITELIST_MAX_PER_ADDRESS=3
export PUBLIC_MAX_PER_ADDRESS=2
export WHITELIST_PRICE=10000000000000000   # 0.01 ETH
export PUBLIC_PRICE=20000000000000000      # 0.02 ETH

forge script script/Deploy.s.sol:CreateTokenScript --rpc-url sepolia --broadcast
```

### Scenario 3: Free Whitelist, Paid Public

```bash
export WHITELIST_PRICE=0
export PUBLIC_PRICE=10000000000000000   # 0.01 ETH
```

### Scenario 4: Multiple Series Management

```solidity
// Token 1: Shapella (ended)
nft.endMintPermanently(1);

// Token 2: Dencun (whitelist active, free)
nft.startWhitelistPhase(2, 0);

// Token 3: Fusaka (not started, configured as paid)
// Wait for the right time to start
```

## 📊 Data Isolation

Each token has completely independent data:

| Data Item              | Description                 |
| ---------------------- | --------------------------- |
| maxSupply              | Maximum supply              |
| whitelistMaxPerAddress | Whitelist per-address limit |
| publicMaxPerAddress    | Public per-address limit    |
| whitelistPrice         | Whitelist price             |
| publicPrice            | Public price                |
| merkleRoot             | Whitelist Merkle Root       |
| phase                  | Current phase status        |
| whitelistMinted        | User whitelist mint records |
| publicMinted           | User public mint records    |

## 🔐 Permission System

### Role Definitions

- **DEFAULT_ADMIN_ROLE** (Highest Permission)

  - Add/remove ADMIN_ROLE
  - Has all ADMIN_ROLE permissions

- **ADMIN_ROLE** (Operational Permission)
  - Create tokens
  - Update configuration
  - Set whitelist
  - Start/end phases
  - Admin mint
  - Withdraw funds

### Multi-Admin Example

```bash
# Add admin
export NEW_ADMIN=0x...
forge script script/Deploy.s.sol:AddAdminScript --rpc-url sepolia --broadcast

# Remove admin
export ADMIN_TO_REMOVE=0x...
forge script script/Deploy.s.sol:RemoveAdminScript --rpc-url sepolia --broadcast
```

## 📦 Script Tools

The project provides comprehensive management scripts:

| Script                      | Function                |
| --------------------------- | ----------------------- |
| `DeployScript`              | Deploy main contract    |
| `CreateTokenScript`         | Create new token        |
| `SetupWhitelistScript`      | Setup whitelist         |
| `StartWhitelistPhaseScript` | Start whitelist phase   |
| `StartPublicPhaseScript`    | Start public phase      |
| `EndMintPermanentlyScript`  | End minting permanently |
| `AdminMintScript`           | Admin mint              |
| `WithdrawScript`            | Withdraw funds          |
| `QueryTokenInfoScript`      | Query token info        |
| `AddAdminScript`            | Add admin               |
| `RemoveAdminScript`         | Remove admin            |

## 🎨 Metadata

The project includes NFT metadata templates:

```json
{
  "name": "Memory of Ethereum #1",
  "description": "Memory of Ethereum is a limited collection...",
  "image": "ipfs://YOUR_CID/image.png",
  "external_url": "https://ethereum.org",
  "attributes": [
    {
      "trait_type": "Collection",
      "value": "Memory of Ethereum"
    }
  ]
}
```

After uploading to IPFS, update BASE_URI:

```bash
# Set in deployment script
string constant BASE_URI = "ipfs://YOUR_CID/";
```

## ⚙️ Configuration

### Foundry Configuration (foundry.toml)

```toml
[profile.default]
solc = "0.8.24"
optimizer = true
optimizer_runs = 200
via_ir = true  # Important: solves Stack too deep issues

[rpc_endpoints]
sepolia = "${SEPOLIA_RPC_URL}"
mainnet = "${MAINNET_RPC_URL}"

[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}" }
mainnet = { key = "${ETHERSCAN_API_KEY}" }
```

### Gas Optimization

- ✅ Using `via_ir` compilation mode
- ✅ Merkle Tree whitelist verification
- ✅ Optimized storage layout
- ✅ Batch operation support

## 🔍 Contract Verification

### Automatic Verification

Verify automatically during deployment:

```bash
npm run deploy:sepolia
```

### Manual Verification

If automatic verification fails:

```bash
export CONTRACT_ADDRESS=0x...
export BASE_URI=ipfs://YOUR_CID/
export DEFAULT_ADMIN=0x...

npm run verify:sepolia
```

See [VERIFY.md](./VERIFY.md) for details.

## 📚 Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [ERC-1155 Standard](https://eips.ethereum.org/EIPS/eip-1155)
- [Merkle Tree](https://en.wikipedia.org/wiki/Merkle_tree)

## 🛡️ Security Considerations

### Implemented Security Measures

- ✅ OpenZeppelin standard contract library
- ✅ Comprehensive unit test coverage
- ✅ Permission control and access restrictions
- ✅ Reentrancy attack protection (OpenZeppelin ReentrancyGuard pattern)
- ✅ Integer overflow protection (Solidity 0.8+)
- ✅ Automatic refund mechanism

### Audit Recommendations

Before mainnet deployment:

- 🔒 Conduct professional security audit
- 🔒 Thoroughly test on testnet
- 🔒 Use multi-sig wallet for DEFAULT_ADMIN_ROLE
- 🔒 Set reasonable supply and prices
- 🔒 Prepare emergency pause mechanism

## 🤝 Contributing

Issues and Pull Requests are welcome!

## 📄 License

MIT License

---

**Built with ❤️ for the Ethereum Community**
