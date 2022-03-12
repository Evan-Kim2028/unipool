// SPDX-License-Identifier: GPLv3
pragma solidity >=0.8.0;

import {ERC20}                  from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ReentrancyGuard}        from "@rari-capital/solmate/src/utils/ReentrancyGuard.sol";
import {FixedPointMathLib}      from "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import {TransferHelper}         from "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import {IERC3156FlashBorrower}  from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

import {UncheckedMathLib}       from "./libraries/UncheckedMathLib.sol";

contract Unipool is ERC20("", "", 18), ReentrancyGuard {

    using UncheckedMathLib for uint256;
    using UncheckedMathLib for uint112;
    using UncheckedMathLib for uint32;

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    event Mint(address indexed sender, uint256 baseAmount, uint256 quoteAmount);
    event Burn(address indexed sender, uint256 baseAmount, uint256 quoteAmount, address indexed to);
    
    event Swap(
        address indexed sender, 
        uint256 baseAmountIn, 
        uint256 quoteAmountIn, 
        uint256 baseAmountOut, 
        uint256 quoteAmountOut, 
        address indexed to
    );
    
    event Sync(uint112 baseReserves, uint112 quoteReserves);

    /* -------------------------------------------------------------------------- */
    /*                                  CONSTANTS                                 */
    /* -------------------------------------------------------------------------- */

    uint256 internal constant Q112 = type(uint112).max;

    uint256 internal constant BIPS_DIVISOR = 10_000;

    // To avoid division by zero, there is a minimum number of liquidity tokens that always 
    // exist (but are owned by account zero). That number is MINIMUM_LIQUIDITY, a thousand.
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;

    /* -------------------------------------------------------------------------- */
    /*                                MUTABLE STATE                               */
    /* -------------------------------------------------------------------------- */

    address public base;   // IE CNV
    address public quote;  // IE DAI

    uint256 public swapFee;
    uint256 public loanFee;

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

    error BAD_FEE();

    // called once by the factory at time of deployment
    function initialize(
        address _base, 
        address _quote, 
        uint256 _swapFee, 
        uint256 _loanFee
    ) external {
        if (_swapFee > 50) revert BAD_FEE();
        if (_loanFee > 50) revert BAD_FEE();

        base = _base;
        quote = _quote;

        swapFee = _swapFee;
        loanFee = _loanFee;

        // permanently lock the first MINIMUM_LIQUIDITY tokens
        _mint(address(0), MINIMUM_LIQUIDITY); 
    }

    error BALANCE_OVERFLOW();

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 baseBalance, uint256 quoteBalance, uint112 _baseReserves, uint112 _quoteReserves) private {
        
        // revert if both balances are greater than 2**112
        if (baseBalance > Q112 && quoteBalance > Q112) revert BALANCE_OVERFLOW();
        
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
        baseReserves = uint112(baseBalance);
        quoteReserves = uint112(quoteBalance);
        lastUpdate = NOW;
        
        emit Sync(baseReserves, quoteReserves);
    }

    error INSUFFICIENT_LIQUIDITY_MINTED();

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        // store any variables used more than once in memory to avoid SLOAD"s
        (uint112 _baseReserves, uint112 _quoteReserves,) = getReserves();
        uint256 baseBalance = ERC20(base).balanceOf(address(this));
        uint256 quoteBalance = ERC20(quote).balanceOf(address(this));
        uint256 baseAmount = baseBalance - (_baseReserves);
        uint256 quoteAmount = quoteBalance - (_quoteReserves);
        uint256 _totalSupply = totalSupply;

        if (_totalSupply == MINIMUM_LIQUIDITY) liquidity = FixedPointMathLib.sqrt(baseAmount * quoteAmount) - MINIMUM_LIQUIDITY;
        
        else liquidity = min((baseAmount * _totalSupply).uDiv(_baseReserves), (quoteAmount * _totalSupply).uDiv(_quoteReserves));
        
        // revert if Lp tokens out is equal to zero
        if (liquidity == 0) revert INSUFFICIENT_LIQUIDITY_MINTED();

        // mint liquidity providers LP tokens
        _mint(to, liquidity);

        // update mutable storage (reserves + cumulative oracle prices)
        _update(baseBalance, quoteBalance, _baseReserves, _quoteReserves);

        emit Mint(msg.sender, baseAmount, quoteAmount);
    }

    error INSUFFICIENT_LIQUIDITY_BURNED();

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external nonReentrant returns (uint256 baseAmount, uint256 quoteAmount) {
        
        // store any variables used more than once in memory to avoid SLOAD"s
        (uint112 _baseReserves, uint112 _quoteReserves,) = getReserves();   
        address _base = base;                                    
        address _quote = quote;                                    
        uint256 baseBalance = ERC20(_base).balanceOf(address(this));          
        uint256 quoteBalance = ERC20(_quote).balanceOf(address(this));          
        uint256 liquidity = balanceOf[address(this)];                 
        uint256 _totalSupply = totalSupply;         

        // division was originally unchecked, using balances ensures pro-rata distribution
        baseAmount = (liquidity * baseBalance).uDiv(_totalSupply); 
        quoteAmount = (liquidity * quoteBalance).uDiv(_totalSupply);
        
        // revert if amountOuts are both equal to zero
        if (baseAmount == 0 && quoteAmount == 0) revert INSUFFICIENT_LIQUIDITY_BURNED();
        
        // burn LP tokens from this contract"s balance
        _burn(address(this), liquidity);
        
        // return liquidity providers underlying tokens
        TransferHelper.safeTransfer(_base, to, baseAmount);
        TransferHelper.safeTransfer(_quote, to, quoteAmount);
        
        // update mutable storage (reserves + cumulative oracle prices)
        _update(ERC20(_base).balanceOf(address(this)), ERC20(_quote).balanceOf(address(this)), _baseReserves, _quoteReserves);
        
        emit Burn(msg.sender, baseAmount, quoteAmount, to);
    }

    error INSUFFICIENT_OUTPUT_AMOUNT();
    error INSUFFICIENT_LIQUIDITY();
    error INSUFFICIENT_INPUT_AMOUNT();
    error INSUFFICIENT_INVARIANT();
    error FLASHSWAPS_NOT_SUPPORTED();

    function swap(uint256 baseAmountOut, uint256 quoteAmountOut, address to, bytes calldata data) external {
        if (data.length > 0) revert FLASHSWAPS_NOT_SUPPORTED();
        swap(baseAmountOut, quoteAmountOut, to);
    }

    function swap(uint256 baseAmountOut, uint256 quoteAmountOut, address to) public nonReentrant {
        // store reserves in memory to avoid SLOAD"s
        (uint112 _baseReserves, uint112 _quoteReserves,) = getReserves();
        
        // revert if sum of amountOut"s is zero
        // revert if either amountOut is greater than it"s underlying reserve
        if (baseAmountOut + quoteAmountOut == 0) revert INSUFFICIENT_OUTPUT_AMOUNT();
        if (baseAmountOut >= _baseReserves && quoteAmountOut >= _quoteReserves) revert INSUFFICIENT_LIQUIDITY();
        
        // store any variables used more than once in memory to avoid SLOAD"s
        uint256 baseAmountIn;
        uint256 quoteAmountIn;
        uint256 _swapFee = swapFee;
        uint256 baseBalance;
        uint256 quoteBalance;
        
        {
        address _base = base;
        address _quote = quote;

        // optimistically transfer "to" base
        // optimistically transfer "to" quote
        if (baseAmountOut > 0) TransferHelper.safeTransfer(_base, to, baseAmountOut); 
        if (quoteAmountOut > 0) TransferHelper.safeTransfer(_quote, to, quoteAmountOut);
        
        // store any variables used more than once in memory to avoid SLOAD"s
        baseBalance = ERC20(_base).balanceOf(address(this));
        quoteBalance = ERC20(_quote).balanceOf(address(this));
        }

        // calculate amountIn"s by comparing last known reserves to current contract balance
        // unchecked math is save here because current balance can only be greater than last
        // known reserves, additionally amountOut"s are checked against reserves above
        if (baseBalance > _baseReserves.uSub(baseAmountOut)) baseAmountIn = baseBalance.uSub(_baseReserves.uSub(baseAmountOut));
        if (quoteBalance > _quoteReserves.uSub(quoteAmountOut)) quoteAmountIn = quoteBalance.uSub(_quoteReserves.uSub(quoteAmountOut));
        // revert if sum of amountIn"s is equal to zero
        // revert if current k adjusted for fees is less than old k
        if (baseAmountIn.uAdd(quoteAmountIn) == 0) revert INSUFFICIENT_INPUT_AMOUNT();   

        if ((baseBalance * BIPS_DIVISOR - baseAmountIn * swapFee) * (quoteBalance * BIPS_DIVISOR - quoteAmountIn * swapFee) < 
            uint(_baseReserves) * _quoteReserves * 1e8) revert INSUFFICIENT_INVARIANT();


        // update mutable storage (reserves + cumulative oracle prices)
        _update(baseBalance, quoteBalance, _baseReserves, _quoteReserves);
        emit Swap(msg.sender, baseAmountIn, quoteAmountIn, baseAmountOut, quoteAmountOut, to);
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
        return amount * loanFee / BIPS_DIVISOR;
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

    // function scaleK(uint256 x, uint256 y, uint256 tk) public pure returns (uint256, uint256) {
    //     unchecked {
    //         uint256 rootK = fsqrt(x*y);
    //         uint256 rootTk = fsqrt(tk);
    //         x *= rootTk / rootK;
    //         y *= rootTk / rootK;
    //         return (x, y);
    //     }
    // }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}
