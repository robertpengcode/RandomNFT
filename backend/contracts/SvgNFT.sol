// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";

contract SvgNFT is ERC721, Ownable {
    uint256 public immutable mintFee;
    string private daySvgImgURI;
    string private nightSvgImgURI;
    uint256 private lastTokenId;

    event SvgNFTMinted(uint256 indexed tokenId, uint256 time);
    event WithdrawByOwner(address indexed owner, uint256 amount, uint256 time);

    error SvgNFT__MintFeeSentNotCorrect();
    error SvgNFT__NonExistentToken();
    error SvgNFT__SentOwnerFailed();

    constructor(uint256 _mintFee, string memory daySvg, string memory nightSvg) ERC721("Dynamic Svg Token", "DST") {
        mintFee = _mintFee;
        daySvgImgURI = svgToImageURI(daySvg);
        nightSvgImgURI = svgToImageURI(nightSvg);
    }

    function mintNFT() external payable{
        if (msg.value != mintFee ) {
            revert SvgNFT__MintFeeSentNotCorrect();
        }
        uint256 tokenId = lastTokenId;
        _safeMint(msg.sender, tokenId);
        lastTokenId++;
        emit SvgNFTMinted(tokenId, block.timestamp);
    }

    function withdraw() external onlyOwner{
        uint256 balance = address(this).balance;
        (bool sentOwner,) = payable(msg.sender).call{value:balance}("");
        if(!sentOwner) {
            revert SvgNFT__SentOwnerFailed();
        }
        emit WithdrawByOwner(msg.sender, balance, block.timestamp);
    }

    function svgToImageURI(string memory svg) public pure returns (string memory) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked(baseURL, svgBase64Encoded));
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    //Epoch timestamp: 1672552800
    //Date and time (GMT): Sunday, January 1, 2023 6:00:00 AM
    //half day = 60 * 60 * 12 = 43,200 seconds

    function isDay() public view returns (bool) {
        return (((block.timestamp - 1672552800) / 43200) % 2 ) == 0;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) {
            revert SvgNFT__NonExistentToken();
        }
        string memory imageURI = daySvgImgURI;
        if (!isDay()) {
            imageURI = nightSvgImgURI;
        }
        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"SvgNFT", "description":"An NFT that changes based on time", ',
                                '"attributes": [{"Test1": "Test1Value", "Test2": "Test2Value"}], "image":"',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

}