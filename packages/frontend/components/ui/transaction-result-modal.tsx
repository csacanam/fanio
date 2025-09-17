"use client"

import { Dialog, DialogContent, DialogHeader, DialogTitle } from './dialog'
import { Button } from './button'
import { CheckCircle, XCircle, ExternalLink, Copy } from 'lucide-react'
import { useState } from 'react'

interface TransactionResultModalProps {
  isOpen: boolean
  onClose: () => void
  isSuccess: boolean
  txHash?: string
  error?: string
  chainId?: number
}

export function TransactionResultModal({
  isOpen,
  onClose,
  isSuccess,
  txHash,
  error,
  chainId = 84532 // Base Sepolia default
}: TransactionResultModalProps) {
  const [copied, setCopied] = useState(false)

  const getExplorerUrl = () => {
    if (!txHash) return ''
    return `https://sepolia.basescan.org/tx/${txHash}`
  }

  const copyToClipboard = async () => {
    if (txHash) {
      await navigator.clipboard.writeText(txHash)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="text-center">
            {isSuccess ? 'Swap Successful!' : 'Swap Failed'}
          </DialogTitle>
        </DialogHeader>
        
        <div className="flex flex-col items-center space-y-4 py-4">
          {/* Icon */}
          <div className={`p-4 rounded-full ${isSuccess ? 'bg-green-100' : 'bg-red-100'}`}>
            {isSuccess ? (
              <CheckCircle className="h-12 w-12 text-green-600" />
            ) : (
              <XCircle className="h-12 w-12 text-red-600" />
            )}
          </div>

          {/* Status Message */}
          <div className="text-center">
            <h3 className={`text-lg font-semibold ${isSuccess ? 'text-green-900' : 'text-red-900'}`}>
              {isSuccess ? 'Transaction Confirmed' : 'Transaction Failed'}
            </h3>
            <p className={`text-sm mt-1 ${isSuccess ? 'text-green-700' : 'text-red-700'}`}>
              {isSuccess 
                ? 'Your swap has been successfully executed on the blockchain.'
                : error || 'The transaction could not be completed.'
              }
            </p>
          </div>

          {/* Transaction Hash */}
          {txHash && (
            <div className="w-full space-y-2">
              <label className="text-sm font-medium text-gray-700">Transaction Hash:</label>
              <div className="flex items-center space-x-2 p-2 bg-gray-50 rounded-md border">
                <code className="flex-1 text-xs font-mono text-gray-800">
                  {`${txHash.slice(0, 10)}...${txHash.slice(-8)}`}
                </code>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={copyToClipboard}
                  className="h-8 w-8 p-0"
                  title="Copy full hash"
                >
                  <Copy className="h-4 w-4" />
                </Button>
              </div>
              {copied && (
                <p className="text-xs text-green-600 text-center">Copied to clipboard!</p>
              )}
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex space-x-3 w-full">
            {txHash && (
              <Button
                variant="outline"
                className="flex-1"
                onClick={() => window.open(getExplorerUrl(), '_blank')}
              >
                <ExternalLink className="h-4 w-4 mr-2" />
                View on Explorer
              </Button>
            )}
            <Button
              onClick={onClose}
              className="flex-1"
              variant={isSuccess ? "default" : "destructive"}
            >
              {isSuccess ? 'Continue' : 'Try Again'}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
