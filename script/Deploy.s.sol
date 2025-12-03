// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MemoryOfEthereumNFT} from "../src/MemoryOfEthereumNFT.sol";

/**
 * @title Deploy Script
 * @dev Deploys MemoryOfEthereumNFT
 */
contract DeployScript is Script {
    string constant NAME = "Memory of Ethereum";
    string constant SYMBOL = "MoE";
    string constant BASE_URI = "https://eip.fun/api/upgrade/";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MemoryOfEthereumNFT nft = new MemoryOfEthereumNFT(
            NAME,
            SYMBOL,
            BASE_URI
        );

        console.log("=== MemoryOfEthereumNFT Deployed ===");
        console.log("Contract Address:", address(nft));
        console.log("Owner:", deployer);
        console.log("Is Admin:", nft.hasRole(nft.ADMIN_ROLE(), deployer));
        console.log("Name:", nft.name());
        console.log("Symbol:", nft.symbol());
        console.log("Current Token ID:", nft.currentTokenId());

        vm.stopBroadcast();
    }
}

/**
 * @title Create Token Script
 * @dev Creates a new token (one Ethereum upgrade)
 */
contract CreateTokenScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        string memory upgradeName = vm.envString("UPGRADE_NAME");
        uint256 maxSupply = vm.envUint("MAX_SUPPLY");
        uint256 whitelistMax = vm.envUint("WHITELIST_MAX_PER_ADDRESS");
        uint256 publicMax = vm.envUint("PUBLIC_MAX_PER_ADDRESS");
        uint256 whitelistPrice = vm.envOr("WHITELIST_PRICE", uint256(0));
        uint256 publicPrice = vm.envOr("PUBLIC_PRICE", uint256(0));
        uint256 whitelistStart = vm.envOr("WHITELIST_START_TIME", uint256(0)); // 0 => skip whitelist
        uint256 publicStart = vm.envOr("PUBLIC_START_TIME", uint256(0));
        bool transferable = vm.envOr("TRANSFERABLE", true);

        vm.startBroadcast(deployerPrivateKey);

        MemoryOfEthereumNFT nft = MemoryOfEthereumNFT(payable(nftAddress));

        uint256 tokenId = nft.createToken(
            upgradeName,
            maxSupply,
            whitelistMax,
            publicMax,
            whitelistPrice,
            publicPrice,
            whitelistStart,
            publicStart,
            transferable
        );

        console.log("=== Token Created ===");
        console.log("Token ID:", tokenId);
        console.log("Upgrade Name:", upgradeName);
        console.log("Max Supply:", maxSupply);
        console.log("Whitelist Max Per Address:", whitelistMax);
        console.log("Public Max Per Address:", publicMax);
        console.log("Whitelist Price:", whitelistPrice);
        console.log("Public Price:", publicPrice);
        console.log("Whitelist Start:", whitelistStart);
        console.log("Public Start:", publicStart);
        console.log("Transferable:", transferable);

        vm.stopBroadcast();
    }
}

/**
 * @title Setup Whitelist Script
 * @dev Sets the whitelist Merkle Root
 */
contract SetupWhitelistScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");

        vm.startBroadcast(deployerPrivateKey);

        MemoryOfEthereumNFT nft = MemoryOfEthereumNFT(payable(nftAddress));
        nft.setMerkleRoot(tokenId, merkleRoot);

        console.log("=== Whitelist Setup ===");
        console.log("Token ID:", tokenId);
        console.log("Merkle Root:", uint256(merkleRoot));

        vm.stopBroadcast();
    }
}

/**
 * @title Set Phase Times Script
 * @dev Updates whitelist/public start times by reusing existing config
 */
contract SetPhaseTimesScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        uint256 whitelistStart = vm.envOr("WHITELIST_START_TIME", uint256(0));
        uint256 publicStart = vm.envOr("PUBLIC_START_TIME", uint256(0));

        vm.startBroadcast(deployerPrivateKey);

        MemoryOfEthereumNFT nft = MemoryOfEthereumNFT(payable(nftAddress));
        (
            ,
            uint256 maxSupply,
            ,
            uint256 whitelistMaxPerAddress,
            uint256 publicMaxPerAddress,
            uint256 whitelistPrice,
            uint256 publicPrice,
            ,
            ,
            ,
            bool transferable
        ) = nft.getTokenInfo(tokenId);

        nft.updateTokenConfig(
            tokenId,
            maxSupply,
            whitelistMaxPerAddress,
            publicMaxPerAddress,
            whitelistPrice,
            publicPrice,
            whitelistStart,
            publicStart
        );

        console.log("=== Phase Times Updated ===");
        console.log("Token ID:", tokenId);
        console.log("Whitelist Start:", whitelistStart);
        console.log("Public Start:", publicStart);
        console.log("Transferable:", transferable);

        vm.stopBroadcast();
    }
}

/**
 * @title End Mint Permanently Script
 * @dev Permanently ends minting
 */
contract EndMintPermanentlyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");

        vm.startBroadcast(deployerPrivateKey);

        MemoryOfEthereumNFT nft = MemoryOfEthereumNFT(payable(nftAddress));

        uint256 remainingSupply = nft.remainingSupply(tokenId);

        console.log("=== Before Ending Mint ===");
        console.log("Token ID:", tokenId);
        console.log("Remaining Supply:", remainingSupply);

        nft.endMintPermanently(tokenId);

        console.log("\n=== After Ending Mint ===");
        console.log("Remaining Supply:", nft.remainingSupply(tokenId));

        vm.stopBroadcast();
    }
}

/**
 * @title Withdraw Funds Script
 * @dev Withdraws contract funds
 */
contract WithdrawScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address payable recipient = payable(vm.envAddress("WITHDRAW_TO"));

        vm.startBroadcast(deployerPrivateKey);

        MemoryOfEthereumNFT nft = MemoryOfEthereumNFT(payable(nftAddress));

        uint256 balance = address(nft).balance;
        console.log("=== Withdraw Funds ===");
        console.log("Contract Balance:", balance);
        console.log("Withdraw To:", recipient);

        nft.withdraw(recipient);

        console.log("Withdrawn Successfully");

        vm.stopBroadcast();
    }
}

/**
 * @title Query Token Info Script
 * @dev Queries token info
 */
contract QueryTokenInfoScript is Script {
    function run() external view {
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        uint256 tokenId = vm.envUint("TOKEN_ID");

        MemoryOfEthereumNFT nft = MemoryOfEthereumNFT(payable(nftAddress));

        (
            string memory upgradeName,
            uint256 maxSupply,
            uint256 currentSupply,
            uint256 whitelistMaxPerAddress,
            uint256 publicMaxPerAddress,
            uint256 whitelistPrice,
            uint256 publicPrice,
            MemoryOfEthereumNFT.MintPhase phase,
            bool ended,
            uint256 mintEndTime,
            bool transferable
        ) = nft.getTokenInfo(tokenId);

        console.log("=== Token Info ===");
        console.log("Token ID:", tokenId);
        console.log("Upgrade Name:", upgradeName);
        console.log("Max Supply:", maxSupply);
        console.log("Current Supply:", currentSupply);
        console.log("Remaining Supply:", nft.remainingSupply(tokenId));
        console.log("");

        console.log("=== Mint Limits ===");
        console.log("Whitelist Max Per Address:", whitelistMaxPerAddress);
        console.log("Public Max Per Address:", publicMaxPerAddress);
        console.log("");

        console.log("=== Prices ===");
        console.log("Whitelist Price:", whitelistPrice);
        console.log("Public Price:", publicPrice);
        console.log("");

        console.log("=== Status ===");
        console.log("Current Phase:", uint256(phase));
        console.log("Mint Ended:", ended);
        console.log("Mint End Time:", mintEndTime);
        console.log("Transferable:", transferable);
    }
}

/**
 * @title Add Admin Script
 * @dev Adds a new admin
 */
contract AddAdminScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address newAdmin = vm.envAddress("NEW_ADMIN");

        vm.startBroadcast(deployerPrivateKey);

        MemoryOfEthereumNFT nft = MemoryOfEthereumNFT(payable(nftAddress));

        console.log("=== Adding Admin ===");
        console.log("New Admin:", newAdmin);

        nft.addAdmin(newAdmin);

        console.log("Is Admin:", nft.isAdmin(newAdmin));

        vm.stopBroadcast();
    }
}

/**
 * @title Remove Admin Script
 * @dev Removes an admin
 */
contract RemoveAdminScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftAddress = vm.envAddress("NFT_ADDRESS");
        address adminToRemove = vm.envAddress("ADMIN_TO_REMOVE");

        vm.startBroadcast(deployerPrivateKey);

        MemoryOfEthereumNFT nft = MemoryOfEthereumNFT(payable(nftAddress));

        console.log("=== Removing Admin ===");
        console.log("Admin to Remove:", adminToRemove);

        nft.removeAdmin(adminToRemove);

        console.log("Is Admin:", nft.isAdmin(adminToRemove));

        vm.stopBroadcast();
    }
}
