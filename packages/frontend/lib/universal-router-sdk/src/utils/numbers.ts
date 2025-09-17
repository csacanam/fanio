// BigNumber is not available in ethers v6, using BigInt instead
import JSBI from 'jsbi'
import bn from 'bignumber.js'
import { Percent } from '@uniswap/sdk-core'
import { toHex } from '@uniswap/v3-sdk'

export function expandTo18DecimalsBN(n: number): bigint {
  // use bn intermediately to allow decimals in intermediate calculations
  return BigInt(new bn(n).times(new bn(10).pow(18)).toFixed())
}

export function expandTo18Decimals(n: number): JSBI {
  return JSBI.BigInt((BigInt(n) * BigInt(10) ** BigInt(18)).toString())
}

export function encodeFeeBips(fee: Percent): string {
  return toHex(fee.multiply(10_000).quotient)
}
