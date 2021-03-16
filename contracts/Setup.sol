// SPDX-License-Identifier: MIT

//https://freezer.finance

pragma solidity 0.6.12;

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IMasterChef {
    function add(uint256 _allocPoint, address _lpToken, uint16 _depositFeeBP, bool _withUpdate) external;
}

contract Setup {

    address wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address factory = 0xBCfCcbde45cE874adCB698cC183deBcF17952812;
    IMasterChef public masterChef;
    bool public status;
    address public token;
    
    constructor(address _token, IMasterChef _masterChef) public{
        token = _token;
        masterChef = _masterChef;
    }

    function setup() external {
        require(status == false, "!status");
        IFactory(factory).createPair(token, busd);
        IFactory(factory).createPair(token, wbnb);

        masterChef.add(4000, IFactory(factory).getPair(token, busd), 0, false); //token-BUSD 0
        masterChef.add(2400, IFactory(factory).getPair(token, wbnb), 0, false); //token-BNB 1

        masterChef.add(500, 0x1B96B92314C44b159149f7E0303511fB2Fc4774f, 400, false); //BNB-BUSD LP 2
        masterChef.add(400, 0xc15fa3E22c912A276550F3E5FE3b0Deb87B55aCd, 400, false); //USDT-BUSD LP 3
        masterChef.add(600, 0x7561EEe90e24F3b348E1087A005F78B4c8453524, 400, false); //BTCB-BNB LP 4
        masterChef.add(600, 0x70D8929d04b60Af4fb9B58713eBcf18765aDE422, 400, false); //ETH-BNB LP 5
        masterChef.add(400, 0x3aB77e40340AB084c3e23Be8e5A6f7afed9D41DC, 400, false); //DAI-BUSD LP 6
        masterChef.add(400, 0x680Dd100E4b394Bda26A59dD5c119A391e747d18, 400, false); //USDC-BUSD LP 7
        masterChef.add(0, 0xc15fa3E22c912A276550F3E5FE3b0Deb87B55aCd, 0, false);     //USDT-BUSD LP Inactive 8
        masterChef.add(600, 0xbCD62661A6b1DEd703585d3aF7d7649Ef4dcDB5c, 400, false); //DOT-BNB LP 9
        masterChef.add(200, 0x0Ed8E0A2D99643e1e65CCA22Ed4424090B8B7458, 400, false); //CAKE-BUSD LP 10
        masterChef.add(200, 0xA527a61703D82139F8a06Bc30097cC9CAA2df5A6, 400, false); //CAKE-BNB LP 11

        masterChef.add(1000, token, 0, false);                                       //TOKEN 12

        masterChef.add(200, 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56, 400, false);  //BUSD 13
        masterChef.add(300, 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c, 400, false);  //WBNB 14
        masterChef.add(100, 0x55d398326f99059fF775485246999027B3197955, 400, false);  //USDT 15
        masterChef.add(200, 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c, 400, false);  //BTCB 16
        masterChef.add(200, 0x2170Ed0880ac9A755fd29B2688956BD959F933F8, 400, false);  //ETH 17
        masterChef.add(100, 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3, 400, false);  //DAI 18
        masterChef.add(100, 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 400, false);  //USDC 19
        masterChef.add(200, 0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402, 400, false);  //DOT 20
        masterChef.add(100, 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82, 400, false);  //CAKE 21
        masterChef.add(100, 0x5Ac52EE5b2a633895292Ff6d8A89bB9190451587, 400, false);  //BSCX 22
        masterChef.add(100, 0xa184088a740c695E156F91f5cC086a06bb78b827, 400, false);  //AUTO 23

        status = true;
    }

}