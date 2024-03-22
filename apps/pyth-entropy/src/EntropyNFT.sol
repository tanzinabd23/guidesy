// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";

contract EntropyNFT is ERC721Enumerable {
    event NumberRequested(uint64 sequenceNumber, address minter);
    event Minted(address minter, uint256 tokenId);

    IEntropy entropy;
    address provider;
    uint256 public constant MAX_SUPPLY = 500;
    uint256 public nextIndex;
    uint256[] private availableTokenIds;

    // Mapping of sequence numbers to minter addresses
    mapping(uint64 => address) public sequenceNumberToMinter;

    constructor(
        address _entropy,
        address _provider
    ) ERC721("EntropyNFT", "eNFT") {
        entropy = IEntropy(_entropy);
        provider = _provider;
        initializeAvailableTokenIds();
    }

    // Initialize array of available token IDs
    function initializeAvailableTokenIds() private {
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            availableTokenIds.push(i);
        }
    }

    // Step 1 of 2: Request a new random number for minting
    // Returns sequence number used to obtain random number from Pyth
    function requestMint(bytes32 userCommitment) external payable {
        require(nextIndex < MAX_SUPPLY, "Reached max supply");

        uint128 requestFee = entropy.getFee(provider);
        require(msg.value >= requestFee, "not enough fees");

        uint64 sequenceNumber = entropy.request{value: requestFee}(
            provider,
            userCommitment,
            true
        );
        sequenceNumberToMinter[sequenceNumber] = msg.sender;

        emit NumberRequested(sequenceNumber, msg.sender);
    }

    // Step 2 of 2: Fulfill mint request using user and Pyth random numbers
    // Ultimate random number is produced from hash of these numbers
    function fulfillMint(
        uint64 sequenceNumber,
        bytes32 userRandomness,
        bytes32 providerRevelation
    ) external {
        bytes32 randomNumber = entropy.reveal(
            provider,
            sequenceNumber,
            userRandomness,
            providerRevelation
        );

        address minter = sequenceNumberToMinter[sequenceNumber];
        uint256 randomIndex = uint256(randomNumber) % availableTokenIds.length;
        uint256 tokenId = availableTokenIds[randomIndex];

        // Swap-and-pop to replace minted tokenId
        availableTokenIds[randomIndex] = availableTokenIds[
            availableTokenIds.length - 1
        ];
        availableTokenIds.pop();
        nextIndex++;

        _safeMint(minter, tokenId);
        emit Minted(minter, tokenId);
    }
}
