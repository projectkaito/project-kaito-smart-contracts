// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC721A.sol";

contract Kaito is Ownable, ERC721A, AccessControl, ReentrancyGuard {
    bytes32 public constant MINT_SIGNER_ROLE = keccak256("MINT_SIGNER_ROLE");
    bytes32 public constant MINT_TYPEHASH = keccak256("Mint(address user,uint256 quantity,uint256 deadline)");
    bytes32 public DOMAIN_SEPARATOR;

    bool public teamMintEnabled = true;
    bool public whitelistMintEnabled = true;
    bool public publicMintEnabled = true;

    uint256 public teamMintStartTimestamp;
    uint256 public whitelistMintStartTimestamp;
    uint256 public publicMintStartTimestamp;

    uint256 public maxTeamMint;
    uint256 public maxWhitelistMint;

    uint256 public teamMintCount;
    uint256 public whitelistMintCount;

    uint256 public maxMintPerWallet = 1;

    string private _baseTokenURI;

    modifier isHuman() {
        require(tx.origin == msg.sender, "Only humans :)");
        _;
    }

    constructor(
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 maxTeamMint_,
        uint256 maxWhitelistMint_
    ) ERC721A("Kaito", "Kaito", maxBatchSize_, collectionSize_) {
        maxTeamMint = maxTeamMint_;
        maxWhitelistMint = maxWhitelistMint_;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Kaito")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mintTeam(
        uint256 deadline,
        uint256 quantity,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external isHuman {
        require(teamMintStartTimestamp < block.timestamp, "Minting will start soon");
        require(totalSupply() + quantity <= collectionSize, "Minting has been finished");
        require(_numberMinted(msg.sender) + quantity <= maxMintPerWallet, "Cannot mint this much tokens");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(MINT_TYPEHASH, msg.sender, quantity, deadline))
            )
        );
        require(deadline >= block.timestamp, "Mint signature expired");
        address signer = ecrecover(digest, v, r, s);
        require(hasRole(MINT_SIGNER_ROLE, signer), "Invalid signature");

        teamMintCount += quantity;
        require(teamMintCount <= maxTeamMint, "Minting reached max cap for team");
        _safeMint(msg.sender, quantity);
    }

    function mintWhitelist(
        uint256 deadline,
        uint256 quantity,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external isHuman {
        require(whitelistMintStartTimestamp < block.timestamp, "Minting will start soon");
        require(totalSupply() + quantity <= collectionSize, "Minting has been finished");
        require(_numberMinted(msg.sender) + quantity <= maxMintPerWallet, "Cannot mint this much tokens");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(MINT_TYPEHASH, msg.sender, quantity, deadline))
            )
        );
        require(deadline >= block.timestamp, "Mint signature expired");
        address signer = ecrecover(digest, v, r, s);
        require(hasRole(MINT_SIGNER_ROLE, signer), "Invalid signature");

        whitelistMintCount += quantity;
        require(whitelistMintCount <= maxWhitelistMint, "Minting reached max cap for team");
        _safeMint(msg.sender, quantity);
    }

    function mint(uint256 quantity) external isHuman {
        require(publicMintEnabled, "Minting is disabled at the moment");
        require(publicMintStartTimestamp < block.timestamp, "Minting will start soon");
        require(totalSupply() + quantity <= collectionSize, "Minting has been finished");
        require(_numberMinted(msg.sender) + quantity <= maxMintPerWallet, "Cannot mint this much tokens");
        _safeMint(msg.sender, quantity);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721A) returns (bool) {
        return AccessControl.supportsInterface(interfaceId) || ERC721A.supportsInterface(interfaceId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function drainEth() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function setOwnersExplicit(uint256 quantity) external onlyOwner nonReentrant {
        _setOwnersExplicit(quantity);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function getOwnershipData(uint256 tokenId) external view returns (TokenOwnership memory) {
        return ownershipOf(tokenId);
    }
}
