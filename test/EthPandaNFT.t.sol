// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EthPandaNFT} from "../src/EthPandaNFT.sol";

contract EthPandaNFTTest is Test {
    EthPandaNFT public nft;
    
    address public owner;
    address public user1;
    address public user2;
    
    string constant NAME = "EthPanda NFT";
    string constant SYMBOL = "EPNFT";
    string constant BASE_URI = "https://api.ethpanda.io/metadata/";
    
    uint256 constant TOKEN_ID_1 = 1;
    uint256 constant TOKEN_ID_2 = 2;
    uint256 constant MAX_SUPPLY_1 = 1000;
    uint256 constant MAX_SUPPLY_2 = 500;
    uint256 constant MINT_PRICE_1 = 0.1 ether;
    uint256 constant MINT_PRICE_2 = 0.2 ether;

    event TokenCreated(uint256 indexed tokenId, uint256 maxSupply, uint256 mintPrice);
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event MintPausedToggled(bool paused);
    event BaseURIUpdated(string newBaseURI);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        nft = new EthPandaNFT(NAME, SYMBOL, BASE_URI);
        
        // 为测试用户提供 ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testInitialState() public view {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
        assertEq(nft.owner(), owner);
        assertEq(nft.mintPaused(), false);
    }

    function testCreateToken() public {
        vm.expectEmit(true, false, false, true);
        emit TokenCreated(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        assertEq(nft.maxSupply(TOKEN_ID_1), MAX_SUPPLY_1);
        assertEq(nft.mintPrice(TOKEN_ID_1), MINT_PRICE_1);
    }

    function testCreateTokenOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
    }

    function testCreateTokenAlreadyExists() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.expectRevert("Token already exists");
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
    }

    function testMint() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit TokenMinted(user1, TOKEN_ID_1, 5);
        
        nft.mint{value: MINT_PRICE_1 * 5}(user1, TOKEN_ID_1, 5);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 5);
        assertEq(nft.totalSupply(TOKEN_ID_1), 5);
    }

    function testMintInsufficientPayment() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        nft.mint{value: MINT_PRICE_1 - 1}(user1, TOKEN_ID_1, 5);
    }

    function testMintExceedsMaxSupply() public {
        nft.createToken(TOKEN_ID_1, 10, MINT_PRICE_1);
        
        vm.prank(user1);
        vm.expectRevert("Exceeds max supply");
        nft.mint{value: MINT_PRICE_1 * 11}(user1, TOKEN_ID_1, 11);
    }

    function testMintTokenDoesNotExist() public {
        vm.prank(user1);
        vm.expectRevert("Token does not exist");
        nft.mint{value: MINT_PRICE_1}(user1, TOKEN_ID_1, 1);
    }

    function testMintWhenPaused() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        nft.toggleMintPause();
        
        vm.prank(user1);
        vm.expectRevert("Minting is paused");
        nft.mint{value: MINT_PRICE_1}(user1, TOKEN_ID_1, 1);
    }

    function testMintRefundsExcess() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        uint256 balanceBefore = user1.balance;
        uint256 overpayment = 1 ether;
        
        vm.prank(user1);
        nft.mint{value: MINT_PRICE_1 + overpayment}(user1, TOKEN_ID_1, 1);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 1);
        assertEq(user1.balance, balanceBefore - MINT_PRICE_1);
    }

    function testMintBatch() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        nft.createToken(TOKEN_ID_2, MAX_SUPPLY_2, MINT_PRICE_2);
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = TOKEN_ID_1;
        tokenIds[1] = TOKEN_ID_2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 3;
        amounts[1] = 2;
        
        uint256 totalPrice = MINT_PRICE_1 * 3 + MINT_PRICE_2 * 2;
        
        vm.prank(user1);
        nft.mintBatch{value: totalPrice}(user1, tokenIds, amounts);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 3);
        assertEq(nft.balanceOf(user1, TOKEN_ID_2), 2);
    }

    function testMintBatchArrayLengthMismatch() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = TOKEN_ID_1;
        tokenIds[1] = TOKEN_ID_2;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        vm.prank(user1);
        vm.expectRevert("Arrays length mismatch");
        nft.mintBatch{value: MINT_PRICE_1}(user1, tokenIds, amounts);
    }

    function testOwnerMint() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        nft.ownerMint(user1, TOKEN_ID_1, 10);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 10);
        assertEq(nft.totalSupply(TOKEN_ID_1), 10);
    }

    function testOwnerMintOnlyOwner() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.prank(user1);
        vm.expectRevert();
        nft.ownerMint(user2, TOKEN_ID_1, 10);
    }

    function testOwnerMintBatch() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        nft.createToken(TOKEN_ID_2, MAX_SUPPLY_2, MINT_PRICE_2);
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = TOKEN_ID_1;
        tokenIds[1] = TOKEN_ID_2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50;
        amounts[1] = 30;
        
        nft.ownerMintBatch(user1, tokenIds, amounts);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 50);
        assertEq(nft.balanceOf(user1, TOKEN_ID_2), 30);
    }

    function testBurn() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.prank(user1);
        nft.mint{value: MINT_PRICE_1 * 10}(user1, TOKEN_ID_1, 10);
        
        vm.prank(user1);
        nft.burn(user1, TOKEN_ID_1, 3);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 7);
        assertEq(nft.totalSupply(TOKEN_ID_1), 7);
    }

    function testBurnBatch() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        nft.createToken(TOKEN_ID_2, MAX_SUPPLY_2, MINT_PRICE_2);
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = TOKEN_ID_1;
        tokenIds[1] = TOKEN_ID_2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 5;
        
        uint256 totalPrice = MINT_PRICE_1 * 10 + MINT_PRICE_2 * 5;
        
        vm.prank(user1);
        nft.mintBatch{value: totalPrice}(user1, tokenIds, amounts);
        
        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 3;
        burnAmounts[1] = 2;
        
        vm.prank(user1);
        nft.burnBatch(user1, tokenIds, burnAmounts);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 7);
        assertEq(nft.balanceOf(user1, TOKEN_ID_2), 3);
    }

    function testSetBaseURI() public {
        string memory newBaseURI = "https://new-api.ethpanda.io/metadata/";
        
        vm.expectEmit(false, false, false, true);
        emit BaseURIUpdated(newBaseURI);
        
        nft.setBaseURI(newBaseURI);
        
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        string memory expectedURI = string(abi.encodePacked(newBaseURI, "1.json"));
        assertEq(nft.uri(TOKEN_ID_1), expectedURI);
    }

    function testSetBaseURIOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setBaseURI("https://new-api.ethpanda.io/metadata/");
    }

    function testToggleMintPause() public {
        assertEq(nft.mintPaused(), false);
        
        vm.expectEmit(false, false, false, true);
        emit MintPausedToggled(true);
        
        nft.toggleMintPause();
        assertEq(nft.mintPaused(), true);
        
        nft.toggleMintPause();
        assertEq(nft.mintPaused(), false);
    }

    function testToggleMintPauseOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.toggleMintPause();
    }

    function testUpdateMaxSupply() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        uint256 newMaxSupply = 2000;
        nft.updateMaxSupply(TOKEN_ID_1, newMaxSupply);
        
        assertEq(nft.maxSupply(TOKEN_ID_1), newMaxSupply);
    }

    function testUpdateMaxSupplyTooLow() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        nft.ownerMint(user1, TOKEN_ID_1, 100);
        
        vm.expectRevert("New max supply too low");
        nft.updateMaxSupply(TOKEN_ID_1, 50);
    }

    function testUpdateMaxSupplyOnlyOwner() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.prank(user1);
        vm.expectRevert();
        nft.updateMaxSupply(TOKEN_ID_1, 2000);
    }

    function testUpdateMintPrice() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        uint256 newPrice = 0.5 ether;
        nft.updateMintPrice(TOKEN_ID_1, newPrice);
        
        assertEq(nft.mintPrice(TOKEN_ID_1), newPrice);
    }

    function testUpdateMintPriceOnlyOwner() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.prank(user1);
        vm.expectRevert();
        nft.updateMintPrice(TOKEN_ID_1, 0.5 ether);
    }

    function testWithdraw() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.prank(user1);
        nft.mint{value: MINT_PRICE_1 * 10}(user1, TOKEN_ID_1, 10);
        
        uint256 contractBalance = address(nft).balance;
        uint256 ownerBalanceBefore = owner.balance;
        
        nft.withdraw();
        
        assertEq(address(nft).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);
    }

    function testWithdrawNoFunds() public {
        vm.expectRevert("No funds to withdraw");
        nft.withdraw();
    }

    function testWithdrawOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.withdraw();
    }

    function testURI() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        string memory expectedURI = string(abi.encodePacked(BASE_URI, "1.json"));
        assertEq(nft.uri(TOKEN_ID_1), expectedURI);
    }

    function testSupportsInterface() public view {
        // ERC1155
        assertTrue(nft.supportsInterface(0xd9b67a26));
        // ERC165
        assertTrue(nft.supportsInterface(0x01ffc9a7));
    }

    function testTransfer() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        vm.prank(user1);
        nft.mint{value: MINT_PRICE_1 * 10}(user1, TOKEN_ID_1, 10);
        
        vm.prank(user1);
        nft.safeTransferFrom(user1, user2, TOKEN_ID_1, 3, "");
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 7);
        assertEq(nft.balanceOf(user2, TOKEN_ID_1), 3);
    }

    function testBatchTransfer() public {
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        nft.createToken(TOKEN_ID_2, MAX_SUPPLY_2, MINT_PRICE_2);
        
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = TOKEN_ID_1;
        tokenIds[1] = TOKEN_ID_2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10;
        amounts[1] = 5;
        
        uint256 totalPrice = MINT_PRICE_1 * 10 + MINT_PRICE_2 * 5;
        
        vm.prank(user1);
        nft.mintBatch{value: totalPrice}(user1, tokenIds, amounts);
        
        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 3;
        transferAmounts[1] = 2;
        
        vm.prank(user1);
        nft.safeBatchTransferFrom(user1, user2, tokenIds, transferAmounts, "");
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), 7);
        assertEq(nft.balanceOf(user1, TOKEN_ID_2), 3);
        assertEq(nft.balanceOf(user2, TOKEN_ID_1), 3);
        assertEq(nft.balanceOf(user2, TOKEN_ID_2), 2);
    }

    // Fuzz testing
    function testFuzzMint(uint96 amount) public {
        vm.assume(amount > 0 && amount <= MAX_SUPPLY_1);
        
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        uint256 totalPrice = MINT_PRICE_1 * amount;
        vm.assume(totalPrice <= user1.balance);
        
        vm.prank(user1);
        nft.mint{value: totalPrice}(user1, TOKEN_ID_1, amount);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), amount);
    }

    function testFuzzOwnerMint(uint96 amount) public {
        vm.assume(amount > 0 && amount <= MAX_SUPPLY_1);
        
        nft.createToken(TOKEN_ID_1, MAX_SUPPLY_1, MINT_PRICE_1);
        
        nft.ownerMint(user1, TOKEN_ID_1, amount);
        
        assertEq(nft.balanceOf(user1, TOKEN_ID_1), amount);
    }

    receive() external payable {}
}

