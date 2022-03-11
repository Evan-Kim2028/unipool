import math

def scaleK(x, y, tk):

    k = x*y

    rootK = math.sqrt(k)
    rootTk = math.sqrt(tk)

    x *= rootTk / rootK
    y *= rootTk / rootK

    assert(x * y == tk)

    print(f'x := {x}')
    print(f'y := {y}')
    print(f'k {x*y} := tk {tk}')

    return rootTk / rootK

print(scaleK(1000e18, 100e18, 1e43));