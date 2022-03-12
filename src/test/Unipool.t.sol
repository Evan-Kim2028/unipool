// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

import "../Unipool.sol";

import "./test.sol";

contract MockContract is ERC20 {
    constructor(
        string memory name, 
        string memory symbol
    ) ERC20(name, symbol, 18) {}

    function mint(address guy, uint256 wad) public {
        _mint(guy, wad);
    }
}

contract UnipoolTest is DSTest {

    MockContract baseToken;
    MockContract quoteToken;
    Unipool pair;

    function setUp() public {
        baseToken = new MockContract("Base Token", "BASE");
        quoteToken = new MockContract("Quote Token", "QUOTE");
        // Pair needs initialized after deployment
        pair = new Unipool();
        pair.initialize(address(baseToken), address(quoteToken), 30, 30);
        baseToken.mint(address(this), 1e27);
        quoteToken.mint(address(this), 1e27);
        baseToken.approve(address(pair), type(uint256).max);
        quoteToken.approve(address(pair), type(uint256).max);
    }

    function addLiquidity(uint baseAmount, uint quoteAmount) internal {
        baseToken.transfer(address(pair), baseAmount);
        quoteToken.transfer(address(pair), quoteAmount);
        pair.mint(address(this));
    }

    function testMint() public {
        uint baseAmount = 1e18;
        uint quoteAmount = 4e18;
        uint expectedLiquidity = 2e18;

        addLiquidity(baseAmount, quoteAmount);

        (uint baseReserves, uint quoteReserves,) = pair.getReserves();
        require(pair.totalSupply() == expectedLiquidity, "make sure pair supply is equal to expected liquidity");
        require(pair.balanceOf(address(this)) == expectedLiquidity - 1000, "make sure pair balance of this contract is equal to expected liquidity minus MIN_LIQ");
        require(baseToken.balanceOf(address(pair)) == baseAmount, "make sure base token balance of pair is equal to base amount");
        require(quoteToken.balanceOf(address(pair)) == quoteAmount, "make sure quote token balance of pair is equal to quote amount");
        require(baseReserves == baseAmount, "make sure base reserves equal base amount");
        require(quoteReserves == quoteAmount, "make sure quote reserves equal quote amount");
    }

    function testSwapBaseToken() public {
        uint baseAmount = 5e18;
        uint quoteAmount = 10e18;
        uint swapAmount = 1e18;
        uint expectedOutputAmount = 1662497915624478906;

        addLiquidity(baseAmount, quoteAmount);

        baseToken.transfer(address(pair), swapAmount);
        
        pair.swap(0, expectedOutputAmount, address(this));

        (uint baseReserves, uint quoteReserves,) = pair.getReserves();
        require(baseReserves == baseAmount + swapAmount, "make sure base reserves equal base amount + swap amount");
        require(quoteReserves == quoteAmount - expectedOutputAmount, "make sure quote reserves equal quote amount - expected output");
        require(baseToken.balanceOf(address(pair)) == baseAmount + swapAmount, "make sure base token balance of this contract equals base amount + swap amount");
        require(quoteToken.balanceOf(address(pair)) == quoteAmount - expectedOutputAmount, "make sure quote token balance of this contract equals quote amount - expected output");
        // // expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(token0Amount).sub(swapAmount))
        // // expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(token1Amount).add(expectedOutputAmount))
    }


    function testSwapQuoteToken() public {
        uint baseAmount = 5e18;
        uint quoteAmount = 10e18;
        uint swapAmount = 1e18;
        uint expectedOutputAmount = 453305446940074565;

        addLiquidity(baseAmount, quoteAmount);

        quoteToken.transfer(address(pair), swapAmount);

        pair.swap(expectedOutputAmount, 0, address(this));

        (uint baseReserves, uint quoteReserves,) = pair.getReserves();
        require(baseReserves == baseAmount - expectedOutputAmount);
        require(quoteReserves == quoteAmount + swapAmount);
        require(baseToken.balanceOf(address(pair)) == baseAmount - expectedOutputAmount);
        require(quoteToken.balanceOf(address(pair)) == quoteAmount + swapAmount);
        // expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(token0Amount).add(expectedOutputAmount))
        // expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(token1Amount).sub(swapAmount))
    }

    function testBurn() public {

        uint baseAmount = 3e18;
        uint quoteAmount = 3e18;
        uint expectedLiquidity = 3e18;

        addLiquidity(baseAmount, quoteAmount);

        pair.transfer(address(pair), expectedLiquidity - 1000);

        pair.burn(address(this));

        require(pair.balanceOf(address(this)) == 0);
        require(pair.totalSupply() == 1000);
        require(baseToken.balanceOf(address(pair)) == 1000);
        require(quoteToken.balanceOf(address(pair)) == 1000);
        uint totalSupplyToken0 = baseToken.totalSupply();
        uint totalSupplyToken1 = quoteToken.totalSupply();
        require(baseToken.balanceOf(address(this)) == totalSupplyToken0 - 1000);
        require(quoteToken.balanceOf(address(this)) == totalSupplyToken1 - 1000);
    }

    // function testPriceCumulativeLast() public {
    //     uint baseAmount = 3e18;
    //     uint quoteAmount = 3e18;
        
    //     addLiquidity(baseAmount, quoteAmount);

    //     (uint baseReserves, uint quoteReserves, uint lastUpdate) = pair.getReserves();
    

    // }
}


//   it('price{0,1}CumulativeLast', async () => {
//     const token0Amount = expandTo18Decimals(3)
//     const token1Amount = expandTo18Decimals(3)
//     await addLiquidity(token0Amount, token1Amount)

//     const blockTimestamp = (await pair.getReserves())[2]
//     await mineBlock(provider, blockTimestamp + 1)
//     await pair.sync(overrides)

//     const initialPrice = encodePrice(token0Amount, token1Amount)
//     expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0])
//     expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1])
//     expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 1)

//     const swapAmount = expandTo18Decimals(3)
//     await token0.transfer(pair.address, swapAmount)
//     await mineBlock(provider, blockTimestamp + 10)
//     // swap to a new price eagerly instead of syncing
//     await pair.swap(0, expandTo18Decimals(1), wallet.address, '0x', overrides) // make the price nice

//     expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10))
//     expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10))
//     expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 10)

//     await mineBlock(provider, blockTimestamp + 20)
//     await pair.sync(overrides)

//     const newPrice = encodePrice(expandTo18Decimals(6), expandTo18Decimals(2))
//     expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10).add(newPrice[0].mul(10)))
//     expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10).add(newPrice[1].mul(10)))
//     expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 20)
//   })
