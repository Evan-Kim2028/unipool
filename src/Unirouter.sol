// // SPDX-License-Identifier: GPLv3
// pragma solidity >=0.8.0;

// import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
// import '@uniswap/lib/contracts/libraries/TransferHelper.sol';


// contract Unirouter {

//     address public immutable WETH;

//     // modifier ensure(uint deadline) {
//     //     require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
//     //     _;
//     // }

//     receive() external payable {
//         // only accept ETH via fallback from the WETH contract
//         assert(msg.sender == WETH); 
//     }


//     // **** ADD LIQUIDITY ****
//     function _addLiquidity(
//         address tokenA,
//         address tokenB,
//         uint amountADesired,
//         uint amountBDesired,
//         uint amountAMin,
//         uint amountBMin
//     ) private returns (uint amountA, uint amountB) {
//         // create the pair if it doesn't exist yet
//         if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) IUniswapV2Factory(factory).createPair(tokenA, tokenB);
//         (uint reserveA, uint reserveB) = getReserves(factory, tokenA, tokenB);
//         if (reserveA == 0 && reserveB == 0) {
//             (amountA, amountB) = (amountADesired, amountBDesired);
//         } else {
//             uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
//             if (amountBOptimal <= amountBDesired) {
//                 require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
//                 (amountA, amountB) = (amountADesired, amountBOptimal);
//             } else {
//                 uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
//                 assert(amountAOptimal <= amountADesired);
//                 require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
//                 (amountA, amountB) = (amountAOptimal, amountBDesired);
//             }
//         }
//     }

//     function addLiquidity(
//         address tokenA,
//         address tokenB,
//         uint amountADesired,
//         uint amountBDesired,
//         uint amountAMin,
//         uint amountBMin,
//         address to,
//         uint deadline
//     ) external returns (uint amountA, uint amountB, uint liquidity) {
//         (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
//         address pair = pairFor(factory, tokenA, tokenB);
//         TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
//         TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
//         liquidity = IUniswapV2Pair(pair).mint(to);
//     }

//     function addLiquidityETH(
//         address token,
//         uint amountTokenDesired,
//         uint amountTokenMin,
//         uint amountETHMin,
//         address to,
//         uint deadline
//     ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
//         (amountToken, amountETH) = _addLiquidity(
//             token,
//             WETH,
//             amountTokenDesired,
//             msg.value,
//             amountTokenMin,
//             amountETHMin
//         );
//         address pair = pairFor(factory, token, WETH);
//         TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
//         IWETH(WETH).deposit{value: amountETH}();
//         assert(IWETH(WETH).transfer(pair, amountETH));
//         liquidity = IUniswapV2Pair(pair).mint(to);
//         if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH); // refund dust eth, if any
//     }

//     // **** REMOVE LIQUIDITY ****
//     function removeLiquidity(
//         address tokenA,
//         address tokenB,
//         uint liquidity,
//         uint amountAMin,
//         uint amountBMin,
//         address to,
//         uint deadline
//     ) public returns (uint amountA, uint amountB) {
//         address pair = pairFor(factory, tokenA, tokenB);
//         IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
//         (uint amount0, uint amount1) = IUniswapV2Pair(pair).burn(to);
//         (address token0,) = sortTokens(tokenA, tokenB);
//         (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
//         require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
//         require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
//     }

//     function removeLiquidityETH(
//         address token,
//         uint liquidity,
//         uint amountTokenMin,
//         uint amountETHMin,
//         address to,
//         uint deadline
//     ) public returns (uint amountToken, uint amountETH) {
//         (amountToken, amountETH) = removeLiquidity(
//             token,
//             WETH,
//             liquidity,
//             amountTokenMin,
//             amountETHMin,
//             address(this),
//             deadline
//         );
//         TransferHelper.safeTransfer(token, to, amountToken);
//         IWETH(WETH).withdraw(amountETH);
//         TransferHelper.safeTransferETH(to, amountETH);
//     }

//     function removeLiquidityWithPermit(
//         address tokenA,
//         address tokenB,
//         uint liquidity,
//         uint amountAMin,
//         uint amountBMin,
//         address to,
//         uint deadline,
//         bool approveMax, uint8 v, bytes32 r, bytes32 s
//     ) external returns (uint amountA, uint amountB) {
//         address pair = pairFor(factory, tokenA, tokenB);
//         uint value = approveMax ? uint(-1) : liquidity;
//         IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
//         (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
//     }

//     function removeLiquidityETHWithPermit(
//         address token,
//         uint liquidity,
//         uint amountTokenMin,
//         uint amountETHMin,
//         address to,
//         uint deadline,
//         bool approveMax, uint8 v, bytes32 r, bytes32 s
//     ) external returns (uint amountToken, uint amountETH) {
//         address pair = pairFor(factory, token, WETH);
//         uint value = approveMax ? uint(-1) : liquidity;
//         IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
//         (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
//     }

//     // **** SWAP ****
//     // requires the initial amount to have already been sent to the first pair
//     function _swap(uint[] memory amounts, address[] memory path, address _to) private {
//         for (uint i; i < path.length - 1; i++) {
//             (address input, address output) = (path[i], path[i + 1]);
//             (address token0,) = sortTokens(input, output);
//             uint amountOut = amounts[i + 1];
//             (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
//             address to = i < path.length - 2 ? pairFor(factory, output, path[i + 2]) : _to;
//             IUniswapV2Pair(pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
//         }
//     }

//     function swapExactTokensForTokens(
//         uint amountIn,
//         uint amountOutMin,
//         address[] calldata path,
//         address to,
//         uint deadline
//     ) external returns (uint[] memory amounts) {
//         amounts = getAmountsOut(factory, amountIn, path);
//         require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
//         TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(factory, path[0], path[1]), amounts[0]);
//         _swap(amounts, path, to);
//     }

//     function swapTokensForExactTokens(
//         uint amountOut,
//         uint amountInMax,
//         address[] calldata path,
//         address to,
//         uint deadline
//     ) external returns (uint[] memory amounts) {
//         amounts = getAmountsIn(factory, amountOut, path);
//         require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
//         TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(factory, path[0], path[1]), amounts[0]);
//         _swap(amounts, path, to);
//     }

//     function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts) {
//         // require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
//         amounts = getAmountsOut(factory, msg.value, path);
//         require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
//         IWETH(WETH).deposit{value: amounts[0]}();
//         assert(IWETH(WETH).transfer(pairFor(factory, path[0], path[1]), amounts[0]));
//         _swap(amounts, path, to);
//     }

//     function swapTokensForExactETH(
//         uint amountOut, 
//         uint amountInMax, 
//         address[] calldata path, 
//         address to, 
//         uint deadline
//     ) external returns (uint[] memory amounts) {
//         // require(path[path.length - 1] == WETH, 'UniswapV2Router: INVALID_PATH');
//         amounts = getAmountsIn(factory, amountOut, path);
//         require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
//         TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(factory, path[0], path[1]), amounts[0]);
//         _swap(amounts, path, address(this));
//         IWETH(WETH).withdraw(amounts[amounts.length - 1]);
//         TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
//     }

//     function swapExactTokensForETH(
//         uint amountIn, 
//         uint amountOutMin, 
//         address[] calldata path, 
//         address to, 
//         uint deadline
//     ) external returns (uint[] memory amounts) {
//         // require(path[path.length - 1] == WETH, 'UniswapV2Router: INVALID_PATH');
//         amounts = getAmountsOut(factory, amountIn, path);
//         require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
//         TransferHelper.safeTransferFrom(path[0], msg.sender, pairFor(factory, path[0], path[1]), amounts[0]);
//         _swap(amounts, path, address(this));
//         IWETH(WETH).withdraw(amounts[amounts.length - 1]);
//         TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
//     }

//     function swapETHForExactTokens(
//         uint amountOut, 
//         address[] calldata path, 
//         address to, 
//         uint deadline
//     ) external payable returns (uint[] memory amounts) {
//         // require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
//         amounts = getAmountsIn(factory, amountOut, path);
//         // require(amounts[0] <= msg.value, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
//         IWETH(WETH).deposit{value: amounts[0]}();
//         assert(IWETH(WETH).transfer(pairFor(factory, path[0], path[1]), amounts[0]));
//         _swap(amounts, path, to);
//         if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]); // refund dust eth, if any
//     }

//     /* -------------------------------------------------------------------------- */
//     /*                              public METHODS                              */
//     /* -------------------------------------------------------------------------- */

//     // returns sorted token addresses, used to handle return values from pairs sorted in this order
//     function sortTokens(
//         address tokenA, 
//         address tokenB
//     ) public pure returns (address token0, address token1) {
//         // require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
//         (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
//         // require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
//     }

//     // calculates the CREATE2 address for a pair without making any external calls
//     function pairFor(
//         address factory, 
//         address tokenA, 
//         address tokenB
//     ) public pure returns (address pair) {
//         (address token0, address token1) = sortTokens(tokenA, tokenB);
//         pair = address(uint(keccak256(abi.encodePacked(
//                 hex'ff',
//                 factory,
//                 keccak256(abi.encodePacked(token0, token1)),
//                 hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
//             ))));
//     }

//     // fetches and sorts the reserves for a pair
//     function getReserves(
//         address factory, 
//         address tokenA, 
//         address tokenB
//     ) public view returns (uint reserveA, uint reserveB) {
//         (address token0,) = sortTokens(tokenA, tokenB);
//         (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
//         (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
//     }

//     // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
//     function quote(
//         uint amountA, 
//         uint reserveA, 
//         uint reserveB
//     ) public pure returns (uint amountB) {
//         // require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
//         // require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
//         amountB = amountA * (reserveB) / reserveA;
//     }

//     // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
//     function getAmountOut(
//         uint amountIn, 
//         uint reserveIn, 
//         uint reserveOut
//     ) public pure returns (uint amountOut) {
//         // require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
//         // require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
//         uint amountInWithFee = amountIn * (997);
//         uint numerator = amountInWithFee * (reserveOut);
//         uint denominator = reserveIn * (1000) + (amountInWithFee);
//         amountOut = numerator / denominator;
//     }

//     // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
//     function getAmountIn(
//         uint amountOut, 
//         uint reserveIn, 
//         uint reserveOut
//     ) public pure returns (uint amountIn) {
//         // require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
//         // require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
//         uint numerator = reserveIn * (amountOut) * (1000);
//         uint denominator = reserveOut - (amountOut) * (997);
//         amountIn = (numerator / denominator) + (1);
//     }

//     // performs chained getAmountOut calculations on any number of pairs
//     function getAmountsOut(
//         address factory, 
//         uint amountIn, 
//         address[] memory path
//     ) public view returns (uint[] memory amounts) {
//         // require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
//         amounts = new uint[](path.length);
//         amounts[0] = amountIn;
//         for (uint i; i < path.length - 1; i++) {
//             (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
//             amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
//         }
//     }

//     // performs chained getAmountIn calculations on any number of pairs
//     function getAmountsIn(
//         address factory, 
//         uint amountOut, 
//         address[] memory path
//     ) public view returns (uint[] memory amounts) {
//         // require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
//         amounts = new uint[](path.length);
//         amounts[amounts.length - 1] = amountOut;
//         for (uint i = path.length - 1; i > 0; i--) {
//             (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
//             amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
//         }
//     }
// }