import math

def scaleK(x, y, tk):

    k = x*y

    rootK = math.sqrt(k)
    rootTk = math.sqrt(tk)

    x *= rootTk / rootK
    y *= rootTk / rootK

    # assert(x * y == tk)

    print(f'x := {x}')
    print(f'y := {y}')
    print(f'k {x*y} := tk {tk}')

    return rootTk / rootK

print(scaleK(1000e18, 100e18, 1e18));


amountIn = 500e18

x = 1000e18

y = 1000e18

scaler = scaleK(x, y, x*y*1e56)

amountOut = y * amountIn / (x + amountIn)

amountOut2 = (y * scaler * amountIn) / (x * scaler + amountIn)

print(amountOut)
print(amountOut2)

print((amountOut2 - amountOut) / amountOut)