// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./ERC721A.sol";

contract Kaito is Ownable, ReentrancyGuard, AccessControl, ERC2981, ERC721A {
    using Strings for uint256;

    bytes32 public constant MINT_SIGNER_ROLE = keccak256("MINT_SIGNER_ROLE");
    bytes32 public constant WHITELIST_MINT_TYPEHASH =
        keccak256("WhitelistMint(address user,uint256 quantity,uint256 deadline)");
    bytes32 public constant TEAM_MINT_TYPEHASH = keccak256("TeamMint(address user,uint256 quantity,uint256 deadline)");
    bytes32 public DOMAIN_SEPARATOR;

    address authorized;

    bool public teamMintEnabled = true;
    bool public whitelistMintEnabled = true;
    bool public publicMintEnabled = true;

    uint256 public teamMintStartTimestamp;
    uint256 public whitelistMintStartTimestamp;
    uint256 public publicMintStartTimestamp;

    uint256 public maxTeamMint;
    uint256 public maxWhitelistMint;
    uint256 public maxPublicMint;

    uint256 public teamMintCount;
    uint256 public whitelistMintCount;
    uint256 public publicMintCount;

    uint256 public constant maxPublicMintPerWallet = 1;
    uint256 public constant maxTeamMintPerWallet = 2;
    uint256 public constant maxWhitelistMintPerWallet = 2;

    mapping(address => bool) public whitelistClaim;
    mapping(address => bool) public teamClaim;

    string private _baseTokenURI;

    modifier isHuman() {
        require(tx.origin == msg.sender, "Only humans :)");
        _;
    }

    modifier onlyOwnerAndAuthorized() {
        require(owner() == _msgSender() || authorized == _msgSender(), "Only authorized!");
        _;
    }

    constructor(
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 maxTeamMint_,
        uint256 maxWhitelistMint_,
        string memory baseTokenUri_,
        uint256 teamMintStartTimestamp_,
        uint256 whitelistMintStartTimestamp_,
        uint256 publicMintStartTimestamp_,
        address owner_
    ) ERC721A("Kaito", "Kaito", maxBatchSize_, collectionSize_) {
        maxTeamMint = maxTeamMint_;
        maxWhitelistMint = maxWhitelistMint_;
        maxPublicMint = collectionSize_ - maxTeamMint_ - maxWhitelistMint_;

        _baseTokenURI = baseTokenUri_;
        teamMintStartTimestamp = teamMintStartTimestamp_;
        whitelistMintStartTimestamp = whitelistMintStartTimestamp_;
        publicMintStartTimestamp = publicMintStartTimestamp_;
        authorized = _msgSender();
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
        _setupRole(DEFAULT_ADMIN_ROLE, owner_);
        grantRole(MINT_SIGNER_ROLE, _msgSender());
        setDefaultRoyalty(owner_, 1000); // 10%
        transferOwnership(owner_);
    }

    function mintTeam(
        uint256 deadline,
        uint256 quantity,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external isHuman {
        require(teamMintEnabled, "Kaito: Team mint is disabled");
        require(teamMintStartTimestamp < block.timestamp, "Kaito: Minting will start soon");
        require(totalSupply() + quantity <= collectionSize, "Kaito: Minting has been finished");
        require(_numberMinted(msg.sender) + quantity <= maxTeamMintPerWallet, "Kaito: Cannot mint this much tokens");
        require(!teamClaim[msg.sender], "Kaito: Team already minted");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(TEAM_MINT_TYPEHASH, msg.sender, quantity, deadline))
            )
        );
        require(deadline >= block.timestamp, "Kaito: Mint signature expired");
        address signer = ecrecover(digest, v, r, s);
        require(hasRole(MINT_SIGNER_ROLE, signer), "Kaito: Invalid signature");

        teamClaim[msg.sender] = true;
        teamMintCount += quantity;
        require(teamMintCount <= maxTeamMint, "Kaito: Minting reached max cap for team");
        _safeMint(msg.sender, quantity);
    }

    function mintWhitelist(
        uint256 deadline,
        uint256 quantity,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external isHuman {
        require(whitelistMintEnabled, "Kaito: Whitelist mint is disabled");
        require(whitelistMintStartTimestamp < block.timestamp, "Kaito: Minting will start soon");
        require(totalSupply() + quantity <= collectionSize, "Kaito: Minting has been finished");
        require(
            _numberMinted(msg.sender) + quantity <= maxWhitelistMintPerWallet,
            "Kaito: Cannot mint this much tokens"
        );
        require(!whitelistClaim[msg.sender], "Kaito: Whitelist already minted");

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(WHITELIST_MINT_TYPEHASH, msg.sender, quantity, deadline))
            )
        );
        require(deadline >= block.timestamp, "Kaito: Mint signature expired");
        address signer = ecrecover(digest, v, r, s);
        require(hasRole(MINT_SIGNER_ROLE, signer), "Kaito: Invalid signature");

        whitelistClaim[msg.sender] = true;
        whitelistMintCount += quantity;
        require(whitelistMintCount <= maxWhitelistMint, "Kaito: Minting reached max cap for whitelist");
        _safeMint(msg.sender, quantity);
    }

    function mint(uint256 quantity) external isHuman {
        require(publicMintEnabled, "Kaito: Minting is disabled at the moment");
        require(publicMintStartTimestamp < block.timestamp, "Kaito: Minting will start soon");
        require(totalSupply() + quantity <= collectionSize, "Kaito: Minting has been finished");
        require(_numberMinted(msg.sender) + quantity <= maxPublicMintPerWallet, "Kaito: Cannot mint this much tokens");
        publicMintCount += quantity;
        require(publicMintCount <= maxPublicMint, "Kaito: Minting reached max cap for public");
        _safeMint(msg.sender, quantity);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC2981, ERC721A)
        returns (bool)
    {
        return
            AccessControl.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId) ||
            ERC721A.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwnerAndAuthorized {
        _baseTokenURI = baseURI;
    }

    function drainEth() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Kaito: Transfer failed.");
    }

    function drainToken(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        token.transfer(to, amount);
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
