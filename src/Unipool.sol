// SPDX-License-Identifier: WTFPL
pragma solidity >=0.8.0;

import {ERC20}                  from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard}        from "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";
import {TransferHelper}         from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import {IERC3156FlashLender}    from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower}  from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

// This library has been tested, and held the highest degree of coding standards
library UncheckedMathLib {
    function uAdd(uint256 x, uint256 y) internal pure returns (uint256 z) {assembly {z := add(x, y)}}
    function uSub(uint256 x, uint256 y) internal pure returns (uint256 z) {assembly {z := sub(x, y)}}
    function uMul(uint256 x, uint256 y) internal pure returns (uint256 z) {assembly {z := mul(x, y)}}
    function uDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {assembly {z := div(x, y)}}
    function uFrac(uint256 x, uint256 y, uint256 denom) internal pure returns (uint256 z) {assembly {z := div(mul(x, y), denom)}}
}

// TODO CHECK REQUIRE STATEMENTS
abstract contract Unipool is ERC20, ReentrancyGuard {

    using UncheckedMathLib for uint256;
    using UncheckedMathLib for uint112;
    using UncheckedMathLib for uint32;

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    
    event Swap(
        address indexed sender, 
        uint256 amount0In, 
        uint256 amount1In, 
        uint256 amount0Out, 
        uint256 amount1Out, 
        address indexed to
    );
    
    event Sync(uint112 baseReserves, uint112 quoteReserves);

    /* -------------------------------------------------------------------------- */
    /*                                  CONSTANTS                                 */
    /* -------------------------------------------------------------------------- */

    uint256 internal constant Q112 = type(uint112).max;

    // To avoid division by zero, there is a minimum number of liquidity tokens that always 
    // exist (but are owned by account zero). That number is MINIMUM_LIQUIDITY, a thousand.
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;

    /* -------------------------------------------------------------------------- */
    /*                                MUTABLE STATE                               */
    /* -------------------------------------------------------------------------- */

    address public base;   // IE CNV
    address public quote;  // IE DAI

    uint256 public basePriceCumulativeLast;
    uint256 public quotePriceCumulativeLast;

    uint112 private baseReserves;   // uses single storage slot, accessible via getReserves
    uint112 private quoteReserves;  // uses single storage slot, accessible via getReserves
    uint32  private lastUpdate;     // uses single storage slot, accessible via getReserves

    function getReserves() public view returns (uint112 _baseReserves, uint112 _quoteReserves, uint32 _lastUpdate) {
        (_baseReserves, _quoteReserves, _lastUpdate) = (baseReserves, quoteReserves, lastUpdate);
    }

    /* -------------------------------------------------------------------------- */
    /*                               INITIALIZATION                               */
    /* -------------------------------------------------------------------------- */

    // called once by the factory at time of deployment
    function initialize(address _base, address _quote) external {
        base = _base;
        quote = _quote;
        // permanently lock the first MINIMUM_LIQUIDITY tokens
        _mint(address(0), MINIMUM_LIQUIDITY); 
    }

    error BALANCE_OVERFLOW();

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _baseReserves, uint112 _quoteReserves) private {
        // revert if either balance is greater than 2**112
        if (balance0 > Q112 && balance1 > Q112) revert BALANCE_OVERFLOW();
        // store current time in memory (mod 2**32 to prevent DoS in 20 years)
        uint32 NOW = uint32(block.timestamp % 2**32);
        // overflow is desired
        uint256 timeElapsed = NOW.uSub(lastUpdate); 
        // if oracle info hasn"t been updated this block, and reserves are greater
        // than zero, update oracle info
        if (timeElapsed > 0 && _baseReserves != 0 && _quoteReserves != 0) {
            basePriceCumulativeLast = basePriceCumulativeLast.uAdd(_quoteReserves.uFrac(Q112, _baseReserves).uMul(timeElapsed));
            quotePriceCumulativeLast = quotePriceCumulativeLast.uAdd(_baseReserves.uFrac(Q112, _quoteReserves).uMul(timeElapsed));
        }
        // sync reserves (make them match balances)
        baseReserves = uint112(balance0);
        quoteReserves = uint112(balance1);
        lastUpdate = NOW;
        emit Sync(baseReserves, quoteReserves);
    }

    error INSUFFICIENT_LIQUIDITY_MINTED();

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        // store any variables used more than once in memory to avoid SLOAD"s
        (uint112 _baseReserves, uint112 _quoteReserves,) = getReserves();
        uint256 balance0 = ERC20(base).balanceOf(address(this));
        uint256 balance1 = ERC20(quote).balanceOf(address(this));
        uint256 amount0 = balance0 - (_baseReserves);
        uint256 amount1 = balance1 - (_quoteReserves);
        uint256 _totalSupply = totalSupply;

        if (_totalSupply == MINIMUM_LIQUIDITY) liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
        else liquidity = min((amount0 * _totalSupply).uDiv(_baseReserves), (amount1 * _totalSupply).uDiv(_quoteReserves));
        
        // revert if Lp tokens out is equal to zero
        if (liquidity == 0) revert INSUFFICIENT_LIQUIDITY_MINTED();
        // mint liquidity providers LP tokens
        _mint(to, liquidity);
        // update mutable storage (reserves + cumulative oracle prices)
        _update(balance0, balance1, _baseReserves, _quoteReserves);
        emit Mint(msg.sender, amount0, amount1);
    }

    error INSUFFICIENT_LIQUIDITY_BURNED();

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        // store any variables used more than once in memory to avoid SLOAD"s
        (uint112 _baseReserves, uint112 _quoteReserves,) = getReserves();   
        address _base = base;                                    
        address _quote = quote;                                    
        uint256 balance0 = ERC20(_base).balanceOf(address(this));          
        uint256 balance1 = ERC20(_quote).balanceOf(address(this));          
        uint256 liquidity = balanceOf[address(this)];                 
        uint256 _totalSupply = totalSupply;                           
        // division was originally unchecked, using balances ensures pro-rata distribution
        amount0 = (liquidity * balance0).uDiv(_totalSupply); 
        amount1 = (liquidity * balance1).uDiv(_totalSupply);
        // revert if amountOuts are both equal to zero
        if (amount0 == 0 && amount1 == 0) revert INSUFFICIENT_LIQUIDITY_BURNED();
        // burn LP tokens from this contract"s balance
        _burn(address(this), liquidity);
        // return liquidity providers underlying tokens
        TransferHelper.safeTransfer(_base, to, amount0);
        TransferHelper.safeTransfer(_quote, to, amount1);
        // update mutable storage (reserves + cumulative oracle prices)
        _update(ERC20(_base).balanceOf(address(this)), ERC20(_quote).balanceOf(address(this)), _baseReserves, _quoteReserves);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    error INSUFFICIENT_OUTPUT_AMOUNT();
    error INSUFFICIENT_LIQUIDITY();
    error INSUFFICIENT_INPUT_AMOUNT();
    error INSUFFICIENT_INVARIANT();
    error FLASHSWAPS_NOT_SUPPORTED();

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        if (data.length > 0) revert FLASHSWAPS_NOT_SUPPORTED();
        swap(amount0Out, amount1Out, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) public nonReentrant {
        // store reserves in memory to avoid SLOAD"s
        (uint112 _baseReserves, uint112 _quoteReserves,) = getReserves();
        // revert if sum of amountOut"s is zero
        // revert if either amountOut is greater than it"s underlying reserve
        if (amount0Out + amount1Out == 0) revert INSUFFICIENT_OUTPUT_AMOUNT();
        if (amount0Out >= _baseReserves || amount1Out >= _quoteReserves) revert INSUFFICIENT_LIQUIDITY();
        // store any variables used more than once in memory to avoid SLOAD"s
        uint256 amount0In;
        uint256 amount1In;
        address _base = base;
        address _quote = quote;
        // optimistically transfer "to" base
        // optimistically transfer "to" quote
        if (amount0Out > 0) TransferHelper.safeTransfer(_base, to, amount0Out); 
        if (amount1Out > 0) TransferHelper.safeTransfer(_quote, to, amount1Out);
        // store any variables used more than once in memory to avoid SLOAD"s
        uint256 balance0 = ERC20(_base).balanceOf(address(this));
        uint256 balance1 = ERC20(_quote).balanceOf(address(this));
        // calculate amountIn"s by comparing last known reserves to current contract balance
        // unchecked math is save here because current balance can only be greater than last
        // known reserves, additionally amountOut"s are checked against reserves above
        if (balance0 > _baseReserves.uSub(amount0Out)) amount0In = balance0.uSub(_baseReserves.uSub(amount0Out));
        if (balance1 > _quoteReserves.uSub(amount1Out)) amount1In = balance1.uSub(_quoteReserves.uSub(amount1Out));
        // revert if sum of amountIn"s is equal to zero
        // revert if current k adjusted for fees is less than old k
        if (amount0In.uAdd(amount1In) == 0) revert INSUFFICIENT_INPUT_AMOUNT();
        if ((balance0 * 1000 - amount0In * 3) * (balance1 * 1000 - amount1In * 3) < _baseReserves * _quoteReserves * 1e6) {
            revert INSUFFICIENT_INVARIANT();
        } 
        // update mutable storage (reserves + cumulative oracle prices)
        _update(balance0, balance1, _baseReserves, _quoteReserves);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external nonReentrant {
        // store any variables used more than once in memory to avoid SLOAD"s
        address _base = base;
        address _quote = quote;
        // transfer unaccounted reserves -> "to"
        TransferHelper.safeTransfer(_base, to, ERC20(_base).balanceOf(address(this)) - (baseReserves));
        TransferHelper.safeTransfer(_quote, to, ERC20(_quote).balanceOf(address(this)) - (quoteReserves));
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        _update(ERC20(base).balanceOf(address(this)), ERC20(quote).balanceOf(address(this)), baseReserves, quoteReserves);
    }

    /* -------------------------------------------------------------------------- */
    /*                                ERC3156 LOGIC                               */
    /* -------------------------------------------------------------------------- */

    function maxFlashLoan(address token) external view returns (uint256) {
        return ERC20(token).balanceOf(address(this));
    }

    function flashFee(address token, uint256 amount) public view returns (uint256) {
        return 0;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        TransferHelper.safeTransfer(token, address(receiver), amount);
        receiver.onFlashLoan(msg.sender, token, amount, 0, data);
        TransferHelper.safeTransferFrom(token, address(receiver), address(this), amount);
        return true;
    }

    /* -------------------------------------------------------------------------- */
    /*                              INTERNAL HELPERS                              */
    /* -------------------------------------------------------------------------- */

    // computes square roots using the babylonian method
    // https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}