# wrapper-contract
Smart contract used to simplify the bridging process

## Interfaces
```
@external
def SwapAndWithdraw(withdrawAsset address, chainAsset address, recipient address):
WIP

```


## Withdrawal Cases

1. ETH -> EOS

ETH -> EOS
EOS.transferWithExtra(A)
EOS.transferWithExtra(B)

2. ETH -> IQ

ETH -> IQ
ETH -> EOS
IQ.transferWithExtra(A)
EOS.transferWithExtra(B)

3. USDT-ERC20 -> IQ

USDT-ERC20.transfer(this)
USDT-ERC20 -> IQ
USDT-ERC20 -> EOS
IQ.transferWithExtra(A)
EOS.transferWithExtra(B)


4. EOS -> ETH

EOS.transfer(this)
EOS -> WETH
WETH -> ETH
ETH.release(A)
ETH.release(B)

5. IQ -> ETH

IQ.transfer(this)
IQ -> WETH
WETH -> ETH
ETH.release(A)
ETH.release(B)

6. IQ -> USDT-ERC20

IQ.transfer(this)
IQ -> USDT-ERC20
IQ -> WETH
WETH -> ETH
USDT-ERC20.transferWithExtra(A)
ETH.release(B)

---

1. Input: ETH / non-ETH
2. Swap: output is ChainAsset / non-ChainAsset
3. Output: ETH / non-ETH


## 