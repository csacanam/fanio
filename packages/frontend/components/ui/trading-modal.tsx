"use client"

import { useState, useEffect } from 'react'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './dialog'
import { Button } from './button'
import { Input } from './input'
import { Label } from './label'
import { ArrowUpDown, TrendingUp, TrendingDown } from 'lucide-react'

interface TradingModalProps {
  isOpen: boolean
  onClose: () => void
  tokenSymbol: string
  currentPrice: number
  onBuy: (amount: number) => Promise<void>
  onSell: (amount: number) => Promise<void>
  usdcBalance: number
  eventTokenBalance: number
  isLoading?: boolean
  initialMode?: 'buy' | 'sell'
}

export function TradingModal({
  isOpen,
  onClose,
  tokenSymbol,
  currentPrice,
  onBuy,
  onSell,
  usdcBalance,
  eventTokenBalance,
  isLoading = false,
  initialMode = 'buy'
}: TradingModalProps) {
  const [mode, setMode] = useState<'buy' | 'sell'>(initialMode)
  const [amount, setAmount] = useState('')
  const [isProcessing, setIsProcessing] = useState(false)
  const [validationError, setValidationError] = useState<string>('')

  // Update mode when initialMode changes
  useEffect(() => {
    setMode(initialMode)
    // Clear validation error when mode changes
    setValidationError('')
  }, [initialMode])

  // Validate amount when it changes
  useEffect(() => {
    if (!amount || parseFloat(amount) <= 0) {
      setValidationError('')
      return
    }

    const numAmount = parseFloat(amount)
    const maxBalance = mode === 'buy' ? usdcBalance : eventTokenBalance

    if (numAmount > maxBalance) {
      setValidationError(`Insufficient balance. You only have ${maxBalance.toFixed(2)} ${mode === 'buy' ? 'USDC' : 'TSBOG'}`)
    } else {
      setValidationError('')
    }
  }, [amount, mode, usdcBalance, eventTokenBalance])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!amount || parseFloat(amount) <= 0) return

    // Check validation before proceeding
    if (validationError) {
      return
    }

    setIsProcessing(true)
    try {
      if (mode === 'buy') {
        // For buy: amount is USDC to spend
        await onBuy(parseFloat(amount))
      } else {
        // For sell: amount is TSBOG to sell
        await onSell(parseFloat(amount))
      }
      setAmount('')
      onClose()
    } catch (error) {
      console.error('Trading error:', error)
    } finally {
      setIsProcessing(false)
    }
  }

  const totalCost = amount ? parseFloat(amount) * currentPrice : 0
  
  // Get the appropriate balance based on mode
  const displayBalance = mode === 'buy' ? usdcBalance : eventTokenBalance
  const displaySymbol = mode === 'buy' ? 'USDC' : tokenSymbol

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {mode === 'buy' ? (
              <>
                <TrendingUp className="h-5 w-5 text-green-600" />
                Buy {tokenSymbol}
              </>
            ) : (
              <>
                <TrendingDown className="h-5 w-5 text-red-600" />
                Sell {tokenSymbol}
              </>
            )}
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          {/* Mode Toggle */}
          <div className="flex rounded-lg border p-1 bg-muted/30">
            <Button
              variant={mode === 'buy' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setMode('buy')}
              className="flex-1"
            >
              <TrendingUp className="h-4 w-4 mr-2" />
              Buy
            </Button>
            <Button
              variant={mode === 'sell' ? 'default' : 'ghost'}
              size="sm"
              onClick={() => setMode('sell')}
              className="flex-1"
            >
              <TrendingDown className="h-4 w-4 mr-2" />
              Sell
            </Button>
          </div>

          {/* Price Info */}
          <div className="flex items-center justify-between p-3 bg-muted/30 rounded-lg">
            <span className="text-sm text-muted-foreground">Current Price</span>
            <span className="font-semibold">${currentPrice.toFixed(2)} USDC</span>
          </div>

          {/* Balance Info */}
          <div className="flex items-center justify-between p-3 bg-muted/30 rounded-lg">
            <span className="text-sm text-muted-foreground">
              {mode === 'buy' ? 'USDC Balance' : `${tokenSymbol} Balance`}
            </span>
            <span className="font-semibold">
              {displayBalance.toFixed(2)} {displaySymbol}
            </span>
          </div>

          {/* Trading Form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="amount">
                {mode === 'buy' ? 'USDC to Spend' : 'TSBOG to Sell'}
              </Label>
              <div className="relative">
                <Input
                  id="amount"
                  type="number"
                  step="0.01"
                  min="0.01"
                  max={mode === 'buy' ? usdcBalance : eventTokenBalance}
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder={mode === 'buy' ? '0.00 USDC' : '0.00 TSBOG'}
                  className="pr-20"
                  disabled={isProcessing}
                />
                <div className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground">
                  {mode === 'buy' ? 'USDC' : 'TSBOG'}
                </div>
              </div>
              {mode === 'buy' && usdcBalance > 0 && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setAmount(usdcBalance.toString())}
                  className="h-6 px-2 text-xs"
                >
                  Max: {usdcBalance.toFixed(2)} USDC
                </Button>
              )}
              {mode === 'sell' && eventTokenBalance > 0 && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setAmount(eventTokenBalance.toString())}
                  className="h-6 px-2 text-xs"
                >
                  Max: {eventTokenBalance.toFixed(2)} TSBOG
                </Button>
              )}
              
              {/* Validation Error */}
              {validationError && (
                <div className="text-sm text-red-600 bg-red-50 p-2 rounded-md border border-red-200">
                  ⚠️ {validationError}
                </div>
              )}
            </div>

            {/* What You'll Receive */}
            {amount && (
              <div className="flex items-center justify-between p-3 bg-muted/30 rounded-lg">
                <span className="text-sm text-muted-foreground">
                  {mode === 'buy' ? 'You\'ll Receive' : 'You\'ll Receive'}
                </span>
                <span className="font-semibold">
                  {mode === 'buy' 
                    ? `${parseFloat(amount).toFixed(2)} TSBOG`
                    : `${totalCost.toFixed(2)} USDC`
                  }
                </span>
              </div>
            )}

            {/* Submit Button */}
            <Button
              type="submit"
              className="w-full"
              disabled={!amount || parseFloat(amount) <= 0 || isProcessing || isLoading || !!validationError}
            >
              {isProcessing ? (
                <>
                  <ArrowUpDown className="h-4 w-4 mr-2 animate-spin" />
                  Processing...
                </>
              ) : (
                <>
                  <ArrowUpDown className="h-4 w-4 mr-2" />
                  {mode === 'buy' ? 'Buy' : 'Sell'} {tokenSymbol}
                </>
              )}
            </Button>
          </form>
        </div>
      </DialogContent>
    </Dialog>
  )
}
