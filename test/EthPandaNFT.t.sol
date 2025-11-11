// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EthPandaNFT} from "../src/EthPandaNFT.sol";

contract EthPandaNFTTest is Test {
    EthPandaNFT public nft;
    
    address public admin;
    address public admin2;
    address public user1;
    address public user2;
    address public user3;
    
    string constant NAME = "EthPanda NFT";
    string constant SYMBOL = "EPNFT";
    string constant BASE_URI = "https://api.ethpanda.io/metadata/";
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    
    bytes32 public merkleRoot;
    bytes32[] public merkleProof1;
    bytes32[] public merkleProof2;

    event WhitelistPhaseStarted(uint256 startTime);
    event PublicPhaseStarted(uint256 startTime);
    event MintPermanentlyEnded(uint256 remainingSupply, uint256 burned);
    event WhitelistMint(address indexed minter, uint256 amount);
    event PublicMint(address indexed minter, uint256 amount);
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    function setUp() public {
        admin = address(this);
        admin2 = makeAddr("admin2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        nft = new EthPandaNFT(NAME, SYMBOL, BASE_URI, admin);
        
        // 为测试用户提供 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        
        // 设置 Merkle Tree (user1 和 user2 在白名单中)
        // 构建一个简单的 2 叶子 Merkle Tree
        bytes32 leaf1 = keccak256(abi.encodePacked(user1));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2));
        
        // 对叶子进行排序以构建 Merkle Tree
        if (uint256(leaf1) < uint256(leaf2)) {
            merkleRoot = keccak256(abi.encodePacked(leaf1, leaf2));
        } else {
            merkleRoot = keccak256(abi.encodePacked(leaf2, leaf1));
        }
        
        // 为 user1 创建 merkle proof
        merkleProof1.push(leaf2);
        
        // 为 user2 创建 merkle proof
        merkleProof2.push(leaf1);
        
        nft.setMerkleRoot(merkleRoot);
    }

    function testInitialState() public view {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertTrue(nft.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(nft.hasRole(ADMIN_ROLE, admin));
        assertEq(uint256(nft.getCurrentPhase()), uint256(EthPandaNFT.MintPhase.NotStarted));
        assertEq(nft.mintEnded(), false);
    }

    function testConstants() public view {
        assertEq(nft.TOKEN_ID(), 1);
        assertEq(nft.MAX_SUPPLY(), 10000);
        assertEq(nft.WHITELIST_MAX_PER_ADDRESS(), 5);
        assertEq(nft.PUBLIC_MAX_PER_ADDRESS(), 1);
        assertEq(nft.PHASE_DURATION(), 2 days);
    }

    function testSetMerkleRoot() public {
        bytes32 newRoot = keccak256("new root");
        nft.setMerkleRoot(newRoot);
        assertEq(nft.merkleRoot(), newRoot);
    }

    function testAddAdmin() public {
        vm.expectEmit(true, false, false, false);
        emit AdminAdded(admin2);
        
        nft.addAdmin(admin2);
        
        assertTrue(nft.hasRole(ADMIN_ROLE, admin2));
        assertTrue(nft.isAdmin(admin2));
    }

    function testAddAdminOnlyDefaultAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.addAdmin(user2);
    }

    function testRemoveAdmin() public {
        nft.addAdmin(admin2);
        
        vm.expectEmit(true, false, false, false);
        emit AdminRemoved(admin2);
        
        nft.removeAdmin(admin2);
        
        assertFalse(nft.hasRole(ADMIN_ROLE, admin2));
        assertFalse(nft.isAdmin(admin2));
    }

    function testRemoveAdminOnlyDefaultAdmin() public {
        nft.addAdmin(admin2);
        
        vm.prank(user1);
        vm.expectRevert();
        nft.removeAdmin(admin2);
    }

    function testIsAdmin() public {
        assertTrue(nft.isAdmin(admin));
        assertFalse(nft.isAdmin(user1));
        
        nft.addAdmin(admin2);
        assertTrue(nft.isAdmin(admin2));
    }

    function testSetMerkleRootOnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setMerkleRoot(keccak256("new root"));
    }

    function testSetMerkleRootBySecondAdmin() public {
        nft.addAdmin(admin2);
        
        bytes32 newRoot = keccak256("new root");
        vm.prank(admin2);
        nft.setMerkleRoot(newRoot);
        
        assertEq(nft.merkleRoot(), newRoot);
    }

    function testStartWhitelistPhase() public {
        vm.expectEmit(false, false, false, false);
        emit WhitelistPhaseStarted(block.timestamp);
        
        nft.startWhitelistPhase();
        
        assertEq(nft.whitelistStartTime(), block.timestamp);
        assertEq(uint256(nft.getCurrentPhase()), uint256(EthPandaNFT.MintPhase.Whitelist));
    }

    function testStartWhitelistPhaseOnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.startWhitelistPhase();
    }

    function testStartWhitelistPhaseRequiresMerkleRoot() public {
        EthPandaNFT nft2 = new EthPandaNFT(NAME, SYMBOL, BASE_URI, admin);
        vm.expectRevert("Merkle root not set");
        nft2.startWhitelistPhase();
    }

    function testStartWhitelistPhaseBySecondAdmin() public {
        nft.addAdmin(admin2);
        
        vm.prank(admin2);
        nft.startWhitelistPhase();
        
        assertEq(nft.whitelistStartTime(), block.timestamp);
    }

    function testCannotStartWhitelistPhaseTwice() public {
        nft.startWhitelistPhase();
        
        vm.expectRevert("Whitelist phase already started");
        nft.startWhitelistPhase();
    }

    function testStartPublicPhase() public {
        nft.startWhitelistPhase();
        
        // 快进 2 天
        vm.warp(block.timestamp + 2 days);
        
        vm.expectEmit(false, false, false, false);
        emit PublicPhaseStarted(block.timestamp);
        
        nft.startPublicPhase();
        
        assertEq(nft.publicStartTime(), block.timestamp);
        assertEq(uint256(nft.getCurrentPhase()), uint256(EthPandaNFT.MintPhase.Public));
    }

    function testStartPublicPhaseRequiresWhitelistEnded() public {
        nft.startWhitelistPhase();
        
        // 只过 1 天
        vm.warp(block.timestamp + 1 days);
        
        vm.expectRevert("Whitelist phase not ended");
        nft.startPublicPhase();
    }

    function testCannotStartPublicPhaseTwice() public {
        nft.startWhitelistPhase();
        vm.warp(block.timestamp + 2 days);
        nft.startPublicPhase();
        
        vm.expectRevert("Public phase already started");
        nft.startPublicPhase();
    }

    function testWhitelistMint() public {
        nft.startWhitelistPhase();
        
        uint256 amount = 3;
        
        vm.expectEmit(true, false, false, true);
        emit WhitelistMint(user1, amount);
        
        vm.prank(user1);
        nft.whitelistMint(amount, merkleProof1);
        
        assertEq(nft.balanceOf(user1, nft.TOKEN_ID()), amount);
        assertEq(nft.whitelistMinted(user1), amount);
        assertEq(nft.totalSupply(nft.TOKEN_ID()), amount);
    }

    function testWhitelistMintMaxAmount() public {
        nft.startWhitelistPhase();
        
        uint256 amount = 5;
        
        vm.prank(user1);
        nft.whitelistMint(amount, merkleProof1);
        
        assertEq(nft.balanceOf(user1, nft.TOKEN_ID()), amount);
    }

    function testWhitelistMintExceedsAllocation() public {
        nft.startWhitelistPhase();
        
        // 先 mint 3 个
        vm.prank(user1);
        nft.whitelistMint(3, merkleProof1);
        
        // 再尝试 mint 3 个（总共 6 个，超过 5 个限制）
        vm.prank(user1);
        vm.expectRevert("Exceeds whitelist allocation");
        nft.whitelistMint(3, merkleProof1);
    }

    function testWhitelistMintInvalidProof() public {
        nft.startWhitelistPhase();
        
        // user3 不在白名单中
        vm.prank(user3);
        vm.expectRevert("Invalid merkle proof");
        nft.whitelistMint(1, merkleProof1);
    }

    function testWhitelistMintNotInPhase() public {
        // 未开始
        vm.prank(user1);
        vm.expectRevert("Not in whitelist phase");
        nft.whitelistMint(1, merkleProof1);
    }

    function testPublicMint() public {
        nft.startWhitelistPhase();
        vm.warp(block.timestamp + 2 days);
        nft.startPublicPhase();
        
        vm.prank(user3);
        vm.expectEmit(true, false, false, true);
        emit PublicMint(user3, 1);
        
        nft.publicMint(1);
        
        assertEq(nft.balanceOf(user3, nft.TOKEN_ID()), 1);
        assertEq(nft.publicMinted(user3), 1);
    }

    function testPublicMintExceedsAllocation() public {
        nft.startWhitelistPhase();
        vm.warp(block.timestamp + 2 days);
        nft.startPublicPhase();
        
        // 先 mint 1 个
        vm.prank(user3);
        nft.publicMint(1);
        
        // 再尝试 mint 1 个（总共 2 个，超过 1 个限制）
        vm.prank(user3);
        vm.expectRevert("Exceeds public allocation");
        nft.publicMint(1);
    }

    function testPublicMintNotInPhase() public {
        nft.startWhitelistPhase();
        
        // 在白名单阶段尝试公开 mint
        vm.prank(user3);
        vm.expectRevert("Not in public phase");
        nft.publicMint(1);
    }

    function testAdminMint() public {
        uint256 amount = 100;
        
        nft.adminMint(user1, amount);
        
        assertEq(nft.balanceOf(user1, nft.TOKEN_ID()), amount);
        assertEq(nft.totalSupply(nft.TOKEN_ID()), amount);
    }

    function testAdminMintOnlyAdmin() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.adminMint(user2, 10);
    }

    function testAdminMintBySecondAdmin() public {
        nft.addAdmin(admin2);
        
        vm.prank(admin2);
        nft.adminMint(user1, 50);
        
        assertEq(nft.balanceOf(user1, nft.TOKEN_ID()), 50);
    }

    function testAdminMintExceedsMaxSupply() public {
        vm.expectRevert("Exceeds max supply");
        nft.adminMint(user1, 10001);
    }

    function testEndMintPermanently() public {
        nft.startWhitelistPhase();
        vm.warp(block.timestamp + 2 days);
        nft.startPublicPhase();
        vm.warp(block.timestamp + 2 days);
        
        // Mint 一些 NFT
        nft.adminMint(user1, 100);
        
        uint256 currentSupply = nft.totalSupply(nft.TOKEN_ID());
        uint256 remainingSupply = nft.MAX_SUPPLY() - currentSupply;
        
        vm.expectEmit(false, false, false, true);
        emit MintPermanentlyEnded(remainingSupply, remainingSupply);
        
        nft.endMintPermanently();
        
        assertEq(nft.mintEnded(), true);
        assertEq(uint256(nft.getCurrentPhase()), uint256(EthPandaNFT.MintPhase.Ended));
        assertEq(nft.remainingSupply(), 0);
    }

    function testEndMintPermanentlyRequiresPhaseEnded() public {
        nft.startWhitelistPhase();
        
        vm.expectRevert("Mint phases not completed");
        nft.endMintPermanently();
    }

    function testCannotMintAfterEndedPermanently() public {
        nft.startWhitelistPhase();
        vm.warp(block.timestamp + 2 days);
        nft.startPublicPhase();
        vm.warp(block.timestamp + 2 days);
        
        nft.endMintPermanently();
        
        // 尝试白名单 mint
        vm.prank(user1);
        vm.expectRevert("Mint has permanently ended");
        nft.whitelistMint(1, merkleProof1);
        
        // 尝试公开 mint
        vm.prank(user3);
        vm.expectRevert("Mint has permanently ended");
        nft.publicMint(1);
        
        // 尝试 admin mint
        vm.expectRevert("Mint has permanently ended");
        nft.adminMint(user1, 1);
    }

    function testBurn() public {
        vm.prank(admin);
        nft.adminMint(user1, 10);
        
        // user1 自己销毁自己的代币，不需要 approval
        uint256 tokenId = nft.TOKEN_ID();
        vm.prank(user1);
        nft.burn(user1, tokenId, 3);
        
        assertEq(nft.balanceOf(user1, tokenId), 7);
        assertEq(nft.totalSupply(tokenId), 7);
    }

    function testSetBaseURI() public {
        string memory newBaseURI = "https://new-api.ethpanda.io/metadata/";
        
        nft.setBaseURI(newBaseURI);
        
        string memory expectedURI = string(abi.encodePacked(newBaseURI, "1.json"));
        assertEq(nft.uri(nft.TOKEN_ID()), expectedURI);
    }

    function testRemainingSupply() public {
        assertEq(nft.remainingSupply(), 10000);
        
        nft.adminMint(user1, 100);
        assertEq(nft.remainingSupply(), 9900);
        
        // End mint permanently
        nft.startWhitelistPhase();
        vm.warp(block.timestamp + 2 days);
        nft.startPublicPhase();
        vm.warp(block.timestamp + 2 days);
        nft.endMintPermanently();
        
        assertEq(nft.remainingSupply(), 0);
    }

    function testWhitelistRemainingForAddress() public {
        nft.startWhitelistPhase();
        
        assertEq(nft.whitelistRemainingForAddress(user1), 5);
        
        vm.prank(user1);
        nft.whitelistMint(3, merkleProof1);
        
        assertEq(nft.whitelistRemainingForAddress(user1), 2);
    }

    function testPublicRemainingForAddress() public {
        nft.startWhitelistPhase();
        vm.warp(block.timestamp + 2 days);
        nft.startPublicPhase();
        
        assertEq(nft.publicRemainingForAddress(user3), 1);
        
        vm.prank(user3);
        nft.publicMint(1);
        
        assertEq(nft.publicRemainingForAddress(user3), 0);
    }

    function testVerifyWhitelist() public {
        address[] memory accounts = new address[](3);
        accounts[0] = user1;
        accounts[1] = user2;
        accounts[2] = user3;
        
        bytes32[][] memory proofs = new bytes32[][](3);
        proofs[0] = merkleProof1;
        proofs[1] = merkleProof2;
        proofs[2] = new bytes32[](0);
        
        bool[] memory results = nft.verifyWhitelist(accounts, proofs);
        
        // 验证结果
        assertEq(results.length, 3);
        assertTrue(results[0]);  // user1 在白名单
        assertTrue(results[1]);  // user2 在白名单
        assertFalse(results[2]); // user3 不在白名单
    }

    function testURIInvalidTokenId() public {
        vm.expectRevert("Invalid token ID");
        nft.uri(999);
    }

    function testSupportsInterface() public view {
        // ERC1155
        assertTrue(nft.supportsInterface(0xd9b67a26));
        // ERC165
        assertTrue(nft.supportsInterface(0x01ffc9a7));
    }

    function testTransfer() public {
        vm.prank(admin);
        nft.adminMint(user1, 10);
        
        // user1 自己转账自己的代币，不需要 approval
        uint256 tokenId = nft.TOKEN_ID();
        vm.startPrank(user1);
        nft.safeTransferFrom(user1, user2, tokenId, 3, "");
        vm.stopPrank();
        
        assertEq(nft.balanceOf(user1, tokenId), 7);
        assertEq(nft.balanceOf(user2, tokenId), 3);
    }

    function testCompleteFlow() public {
        // 1. 设置白名单并开始白名单阶段
        nft.startWhitelistPhase();
        assertEq(uint256(nft.getCurrentPhase()), uint256(EthPandaNFT.MintPhase.Whitelist));
        
        // 2. 白名单用户 mint
        vm.prank(user1);
        nft.whitelistMint(5, merkleProof1);
        assertEq(nft.balanceOf(user1, nft.TOKEN_ID()), 5);
        
        vm.prank(user2);
        nft.whitelistMint(3, merkleProof2);
        assertEq(nft.balanceOf(user2, nft.TOKEN_ID()), 3);
        
        // 3. 快进到公开阶段
        vm.warp(block.timestamp + 2 days);
        nft.startPublicPhase();
        assertEq(uint256(nft.getCurrentPhase()), uint256(EthPandaNFT.MintPhase.Public));
        
        // 4. 公开 mint
        vm.prank(user3);
        nft.publicMint(1);
        assertEq(nft.balanceOf(user3, nft.TOKEN_ID()), 1);
        
        // 5. 快进到公开阶段结束
        vm.warp(block.timestamp + 2 days);
        assertEq(uint256(nft.getCurrentPhase()), uint256(EthPandaNFT.MintPhase.Ended));
        
        // 6. 永久结束 mint
        nft.endMintPermanently();
        
        assertEq(nft.mintEnded(), true);
        assertEq(nft.remainingSupply(), 0);
        
        // 7. 验证所有 mint 功能都被禁用
        vm.prank(user1);
        vm.expectRevert("Mint has permanently ended");
        nft.whitelistMint(1, merkleProof1);
        
        // 8. 但转账和销毁功能仍可用
        uint256 tokenId = nft.TOKEN_ID();
        vm.prank(user1);
        nft.safeTransferFrom(user1, user3, tokenId, 2, "");
        assertEq(nft.balanceOf(user3, tokenId), 3);
        
        vm.prank(user1);
        nft.burn(user1, tokenId, 1);
        assertEq(nft.balanceOf(user1, tokenId), 2);
    }

    // Fuzz testing
    function testFuzzWhitelistMint(uint8 amount) public {
        vm.assume(amount > 0 && amount <= 5);
        
        nft.startWhitelistPhase();
        
        vm.prank(user1);
        nft.whitelistMint(amount, merkleProof1);
        
        assertEq(nft.balanceOf(user1, nft.TOKEN_ID()), amount);
    }

    function testFuzzAdminMint(uint16 amount) public {
        vm.assume(amount > 0 && amount <= 10000);
        
        nft.adminMint(user1, amount);
        
        assertEq(nft.balanceOf(user1, nft.TOKEN_ID()), amount);
    }

    receive() external payable {}
}
