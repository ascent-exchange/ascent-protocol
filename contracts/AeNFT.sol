// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title aeNFT contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract aeNFT is ERC721Enumerable, Ownable {
    using SafeERC20 for IERC20;

    // Base URI
    string private _baseURIextended;
    uint256 public MAX_SUPPLY;
    uint256 public NFT_PRICE;
    uint256 public MAX_PER_MINT = 10;
    uint256 public MAX_PER_WALLET;
    uint256 public reservedAmount;
    bytes32 public root;
    mapping(address => bool) public whitelist;

    bool public saleIsEnabled;
    bool public whitelistSaleIsEnabled;

    mapping(address => uint256) public originalMinters;

    constructor(
        uint256 _maxSupply,
        uint256 _nftPrice
    ) ERC721("aeNFT", "aeNFT") {
        MAX_SUPPLY = _maxSupply;
        NFT_PRICE = _nftPrice;
    }

    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function setRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    function setNftPrice(uint256 _nftPrice) external onlyOwner {
        NFT_PRICE = _nftPrice;
    }

    function setMaxPerMint(uint256 value) external onlyOwner {
        MAX_PER_MINT = value;
    }

    function setMaxPerWallet(uint256 value) external onlyOwner {
        MAX_PER_WALLET = value;
    }

    function setSaleState() external onlyOwner {
        saleIsEnabled = !saleIsEnabled;
    }

    function setWhitelistSaleState() external onlyOwner {
        whitelistSaleIsEnabled = !whitelistSaleIsEnabled;
    }

    function setWhitelist(address[] memory users, bool value) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = value;
        }
    }

    /**
     * Mint NFTs by owner
     */
    function reserveNFTs(address to, uint256 amount) external onlyOwner {
        _mintTo(to, amount);
        reservedAmount = reservedAmount + amount;
    }

    /**
     * @dev Return the base URI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    /**
     * @dev Return the base URI
     */
    function baseURI() external view returns (string memory) {
        return _baseURI();
    }

    /**
     * @dev Set the base URI
     */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIextended = baseURI_;
    }

    /**
     * Get the array of token for owner.
     */
    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 index; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    function verifyLeaf(bytes32[] memory proof, address sender) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(keccak256(abi.encodePacked(sender))));
        return MerkleProof.verify(proof, root, leaf);
    }

    /**
     * Whitelist Mint
     */
    function mintWhitelist(bytes32[] memory proof, uint256 amount) public payable {
        require(whitelistSaleIsEnabled, "Whitelist Sale has not opened.");
        require(amount <= MAX_PER_MINT, "Can only mint 10 NFTs at a time");
        require(MAX_PER_WALLET == 0 || balanceOf(msg.sender) + amount <= MAX_PER_WALLET, "Would exceed max limit");
        require(whitelist[msg.sender] || verifyLeaf(proof, msg.sender), "Not whitelisted.");
        require(NFT_PRICE * amount == msg.value, "MATIC value sent is not correct");

        originalMinters[msg.sender] = originalMinters[msg.sender] + amount;
        _mintTo(msg.sender, amount);
    }

    /**
     * Mint NFTs
     */
    function mintPublic(uint256 amount) public payable {
        require(saleIsEnabled, "Public Sale has not opened.");
        require(amount <= MAX_PER_MINT, "Can only mint 10 NFTs at a time");
        require(MAX_PER_WALLET == 0 || balanceOf(msg.sender) + amount <= MAX_PER_WALLET, "Would exceed max limit");
        require(NFT_PRICE * amount == msg.value, "MATIC value sent is not correct");

        originalMinters[msg.sender] = originalMinters[msg.sender] + amount;
        _mintTo(msg.sender, amount);
    }

    function _mintTo(address account, uint amount) internal {
        require(totalSupply() + amount <= MAX_SUPPLY, "Mint would exceed max supply.");

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(account, totalSupply());
        }
    }
}
