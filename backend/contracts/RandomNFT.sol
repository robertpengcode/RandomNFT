// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract RandomNFT is ERC721, ERC721URIStorage, Ownable, VRFConsumerBaseV2 {
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    uint256 public lastTokenId;
    uint256 public immutable i_mintFee;
    uint256[] public tokenURIIdsArr;
    string[] public tokenURIArr;
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    mapping(uint256 => address) private requestIdToBuyers; /* requestId --> nft buyers */

    //Chainlink VRF variables
    VRFCoordinatorV2Interface COORDINATOR;
    // Your subscription ID.
    uint64 s_subscriptionId;
    uint256 public lastRequestId;
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    // bytes32 keyHash =
    //     0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    bytes32 keyHash =
        //https://docs.chain.link/vrf/v2/subscription/supported-networks#avalanche-fuji-testnet
        0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;    
    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    //uint32 callbackGasLimit = 100000;
    uint32 callbackGasLimit = 1000000;
    uint16 requestConfirmations = 3;
    // retrieve 1 random values in one request.
    uint32 numWords = 1;
    /**
     * HARDCODED FOR GOERLI
     * COORDINATOR: 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D
     */
    /**
     * Avalanche Fuji testnet
     * COORDINATOR: 0x2eD832Ba664535e5886b75D64C46EB9a228C2610
     */
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event WithdrawByOwner(address owner, uint256 amount, uint256 time);
    event NftMinted(uint256 tokenId, address buyer);

    error RandomNFT__NotEnoughFundToMint();
    error RandomNFT__NoMoreNFT();
    error RandomNFT__SentOwnerFailed();

    //10000000000000000
    //["testURI1","testURI2","testURI3","testURI4","testURI5"]

    constructor(uint64 subscriptionId, uint256 mintFee, string[] memory _tokenURIArr) ERC721("NZToken", "NZT") VRFConsumerBaseV2(0x2eD832Ba664535e5886b75D64C46EB9a228C2610)
        {
            COORDINATOR = VRFCoordinatorV2Interface(
            0x2eD832Ba664535e5886b75D64C46EB9a228C2610
        );
        s_subscriptionId = subscriptionId;
        i_mintFee = mintFee;
        tokenURIArr = _tokenURIArr;
        generateIdArr(_tokenURIArr.length);
    }

    // Assumes the subscription is funded sufficiently.
    function mintNFT()
        external
        payable
        returns (uint256 requestId)
    {
        if (tokenURIIdsArr.length == 0) {
            revert RandomNFT__NoMoreNFT();
        }
        if (msg.value < i_mintFee) {
            revert RandomNFT__NotEnoughFundToMint();
        }
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        lastRequestId = requestId;
        requestIdToBuyers[requestId] = msg.sender;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
        uint256 _id = _randomWords[0] % tokenURIIdsArr.length;
        uint256 _tokenURIId = tokenURIIdsArr[_id];
        address buyer = requestIdToBuyers[_requestId];
        safeMint(buyer, tokenURIArr[_tokenURIId]);
        tokenURIIdsArr[_id] = tokenURIIdsArr[tokenURIIdsArr.length-1];
        tokenURIIdsArr.pop();
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function safeMint(address to, string memory uri) public {
        uint256 _tokenId = lastTokenId;
        lastTokenId++;
        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);
        emit NftMinted(_tokenId, to);
    }

    function withdraw() external onlyOwner{
        uint256 balance = address(this).balance;
        (bool sentOwner,) = payable(msg.sender).call{value: balance}("");
        if (!sentOwner) {
            revert RandomNFT__SentOwnerFailed();
        }
        emit WithdrawByOwner(msg.sender, balance, block.timestamp);
    }

    function generateIdArr(uint256 arrLength) internal{
        for (uint256 i = 0; i < arrLength; i++) {
            tokenURIIdsArr.push(i);
        }
    }

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function getMintFee() external view returns(uint256) {
        return i_mintFee;
    }
}