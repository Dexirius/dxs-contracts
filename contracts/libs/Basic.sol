// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Basic is Ownable {
    mapping(address => bool) public mod;
    mapping(address => bool) public support;
    
    modifier onlyMod() {
        require(mod[msg.sender] || msg.sender == owner(), "Must be mod");
        _;
    }

    modifier onlySupport() {
        require(support[msg.sender] || msg.sender == owner(), "Must be support");
        _;
    }    

    function addMod(address _mod) public onlyOwner {
        if (_mod != address(0x0) && _mod != address(0)) {
            mod[_mod] = true;
        }
    }

    function addSupport(address _support) public onlyOwner {
        if (_support != address(0x0) && _support != address(0)) {
            support[_support] = true;
        }
    }    

    function removeMod(address _mod) public onlyOwner {
        if (mod[_mod]) {
            mod[_mod] = false;
        }
    }

    function removeSupport(address _support) public onlyOwner {
        if (support[_support]) {
            support[_support] = false;
        }
    }    

    constructor() public Ownable() {}
}
