// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test ,console} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {DeployToken} from "../script/DeployToken.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract TestToken is Test{
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    Token public token;
    DeployToken public deployer;

    //Making test addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 private constant STARTING_BALANCE = 100 ether;

    function setUp() external {
        deployer = new DeployToken();
        token = deployer.run();
    }

    function getOwnerAddress() public view returns(address){
        return address(this);
        console.log(address(this));
    }

    function testIntialBalanceShouldBeZero() public {
        assertEq(token.balanceOf(bob),0);
    }

    function testNameIsCorrect() public view { 
        string memory expectedName = "CollegeDAO";
        string memory actualName = token.name();

        assert(keccak256(abi.encodePacked(expectedName)) == keccak256(abi.encodePacked(actualName)));
    }

    function testSymbolIsCorrect() public view {
        string memory expectedSymbol = "JNTUH";
        string memory actualSymbol = token.symbol();

        assert(keccak256(abi.encodePacked(expectedSymbol)) == keccak256(abi.encodePacked(actualSymbol)));
    }

    function testSafeMintCanOnlyBeCalledByTheOwner() public {
        vm.prank(bob);
        vm.expectRevert();
        token.safeMint(alice,"nft");
    }

    function testOnePersonCannotHaveMoreThanOneNft() public {
        vm.prank(msg.sender);
        token.safeMint(bob,"nft");
        assertEq(token.getTokenCount(),1);
        
        vm.prank(msg.sender);
        vm.expectRevert();
        token.safeMint(bob,"nft2");
    }

    function testIfTheTokenIdCounterWorks() public {
        vm.prank(msg.sender);
        token.safeMint(bob,"nft");
        assertEq(token.getTokenCount(),1);

        vm.prank(msg.sender);
        token.safeMint(alice,"nft1");
        assertEq(token.getTokenCount(),2);
    }

    function testTheSafeMintFunctionWorks() public {
        assertEq(token.balanceOf(bob),0);

        vm.prank(msg.sender);
        token.safeMint(bob,"nft");
        assertEq(token.balanceOf(bob),1);
        assertEq(token.ownerOf(0),bob);
    }

    function testTokenURIWhenSafeMint() public {
        vm.prank(msg.sender);
        token.safeMint(bob,"nft");

        assert(keccak256(abi.encodePacked(token.tokenURI(0))) == keccak256(abi.encodePacked("nft")));
    }

    function testBurnCanBeOnlyCalledByTheOwnerOfToken() public {
        vm.prank(msg.sender);
        token.safeMint(bob,"nft");

        vm.prank(alice);
        vm.expectRevert();
        token.burn(0);

        vm.prank(msg.sender);
        vm.expectRevert();
        token.burn(0);
    }

    function testBurnWorks() public {
        vm.prank(msg.sender);
        token.safeMint(bob,"nft");
        assertEq(token.balanceOf(bob),1);
        assertEq(token.ownerOf(0),bob);

        vm.prank(bob);
        token.burn(0);
        assertEq(token.balanceOf(bob),0);
    }

    function testRevokeCanBeCalledOnlyByOwner() public {
        vm.prank(msg.sender);
        token.safeMint(bob,"nft");
        assertEq(token.balanceOf(bob),1);
        assertEq(token.ownerOf(0),bob);

        vm.prank(bob);
        vm.expectRevert();
        token.revoke(0);
    }

    function testRevokeWorks() public {
        vm.prank(msg.sender);
        token.safeMint(bob,"nft");
        assertEq(token.balanceOf(bob),1);
        assertEq(token.ownerOf(0),bob);

        vm.prank(msg.sender);
        token.revoke(0);
        assertEq(token.balanceOf(bob),0);
    }
 


}