<img align="right" width="400" height="150" top="100" src="./assets/readme.png">

# Unipool 🦄 • [![tests](https://github.com/abigger87/femplate/actions/workflows/tests.yml/badge.svg)](https://github.com/abigger87/femplate/actions/workflows/tests.yml) [![lints](https://github.com/abigger87/femplate/actions/workflows/lints.yml/badge.svg)](https://github.com/abigger87/femplate/actions/workflows/lints.yml) ![GitHub](https://img.shields.io/github/license/abigger87/femplate)  ![GitHub package.json version](https://img.shields.io/github/package-json/v/abigger87/femplate)


## Getting Started

The idea here is simple, create an experimental AMM with more features at a lower gas cost. In my opinion, the largest barrier-to-entry for emerging AMMs is liquidity, or lack thereof. Due to the nature of constant product market makers, the less liquidity pools have the more slippage their users incur while trading. However, what if we could imitate deeper pools, without the underlying liquidity?



Well, we know ![xy=k](https://latex.codecogs.com/svg.image?xy=k) equals the constant product market curve where 
* ![x](https://latex.codecogs.com/svg.image?x) = token x reserves
* ![y](https://latex.codecogs.com/svg.image?y) = token y reserves
* ![k](https://latex.codecogs.com/svg.image?k) = constant/invariant

First observe that ![k=c^2](https://latex.codecogs.com/svg.image?k=c^2) for some real number ![c](https://latex.codecogs.com/svg.image?c) so we can rewrite  the constant product market curve as 

![xy=k](https://latex.codecogs.com/svg.image?xy=k)

![xy=c^2](https://latex.codecogs.com/svg.image?xy=c^2)


![xy/c=c](https://latex.codecogs.com/svg.image?\frac{xy}{c}=c)

![1/c*xy=c](https://latex.codecogs.com/svg.image?\frac{1}{c}xy=c)


where ![\frac{1}{c}](https://latex.codecogs.com/svg.image?1/c) is the invariant of the constant product market curve. 

Suppose we want to target a specific constant ![k](https://latex.codecogs.com/svg.image?k) which directly allows us to control price impact on the pool. Observe again that we could let ![k=c^2](https://latex.codecogs.com/svg.image?k=c^2) for some real number ![c](https://latex.codecogs.com/svg.image?c) such that ![c=ab](https://latex.codecogs.com/svg.image?c=ab) for ![a!=b](https://latex.codecogs.com/svg.image?a&space;\neq&space;b). By controlling the values of ![a](https://latex.codecogs.com/svg.image?a) and ![b](https://latex.codecogs.com/svg.image?b), we can construct any ![k](https://latex.codecogs.com/svg.image?k) for any $xy$ pool. Note that if ![a=b](https://latex.codecogs.com/svg.image?a=b), then we get the traditional constant product market curve. Working backwards from the above equation and replacing ![c](https://latex.codecogs.com/svg.image?c) with ![a,b](https://latex.codecogs.com/svg.image?a,b), we get



![(1/ab)xy=ab](https://latex.codecogs.com/svg.image?\bg{white}\frac{1}{ab}xy=ab&space;)

![(xy/ab)=ab](https://latex.codecogs.com/svg.image?\frac{xy}{ab}=ab)

![xy=(ab)^2=c^2](https://latex.codecogs.com/svg.image?xy=(ab)^2=c^2)

![xy=k](https://latex.codecogs.com/svg.image?xy=k)



where ![k](https://latex.codecogs.com/svg.image?k) is now a different constant than the one we started with and 

![xy=k](https://latex.codecogs.com/svg.image?1/ab) is called the target invariant. ![square](https://latex.codecogs.com/svg.image?\square)



## Features

* ♻️Invariant imitation
* ✅Removed Uniswap LP fee
* ✅Added swap fee customization
* ✅Added ERC3156 Flash-loan support (to save gas)
* ✅Optional TWAP support (to save gas)


## Blueprint

```ml
lib
├─ ds-test — https://github.com/dapphub/ds-test
├─ solmate — https://github.com/Rari-Capital/solmate
src
├─ tests
│  └─ Unipool.t — "Unipool Tests"
└─ Unipool — "A Minimal Unipool Contract"
```

## License

[AGPL-3.0-only](https://github.com/abigger87/unipool/blob/master/LICENSE)

## Acknowledgements

- [foundry](https://github.com/gakonst/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [forge-std](https://github.com/brockelmore/forge-std)
- [foundry-toolchain](https://github.com/onbjerg/foundry-toolchain) by [onbjerg](https://github.com/onbjerg).

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
