'use client'

import { useState, useEffect, useRef } from 'react'
import {
  useWriteContract,
  useWaitForTransactionReceipt,
  useAccount,
  useReadContract,
} from 'wagmi'
import { parseUnits, formatUnits, zeroAddress } from 'viem'
import { mockStablecoinAbi, TOKEN_ADDRESS } from '@/lib/contracts'
import { parseRevertReason } from '@/lib/errors'
import { useToast } from '@/contexts/ToastContext'
import { ConnectWallet } from '@/components/ConnectWallet'

type FormState = 'idle' | 'pending' | 'done' | 'error'

export function FaucetClient() {
  const [amountStr, setAmountStr] = useState('1000')
  const [formState, setFormState] = useState<FormState>('idle')
  const mintToastId = useRef<string | null>(null)

  const { address, isConnected } = useAccount()
  const { addToast, updateToast } = useToast()

  const { data: balance, refetch: refetchBalance } = useReadContract({
    address: TOKEN_ADDRESS,
    abi: mockStablecoinAbi,
    functionName: 'balanceOf',
    args: [address ?? zeroAddress],
    query: { enabled: isConnected && !!address },
  })

  const {
    writeContract: mintWrite,
    data: mintTxHash,
    error: mintWriteError,
    reset: resetMintWrite,
  } = useWriteContract()

  const {
    isSuccess: mintConfirmed,
    isError: mintReceiptFailed,
    error: mintReceiptError,
  } = useWaitForTransactionReceipt({ hash: mintTxHash })

  // Effect 1 — mint confirmed → 'done', refetch balance
  useEffect(() => {
    if (mintConfirmed && formState === 'pending') {
      setFormState('done')
      void refetchBalance()
    }
  }, [mintConfirmed, formState, refetchBalance])

  // Effect 2 — write error (wallet rejection / pre-broadcast failure)
  useEffect(() => {
    if (mintWriteError && formState !== 'idle') {
      setFormState('error')
    }
  }, [mintWriteError, formState])

  // Effect 3 — receipt error (on-chain revert / replacement / dropped)
  useEffect(() => {
    if (mintReceiptFailed && formState === 'pending') {
      setFormState('error')
    }
  }, [mintReceiptFailed, formState])

  // Effect 4 — toast: tx submitted
  useEffect(() => {
    if (mintTxHash && !mintToastId.current) {
      mintToastId.current = addToast('pending', 'Mint transaction submitted...')
    }
  }, [mintTxHash, addToast])

  // Effect 5 — toast: confirmed
  useEffect(() => {
    if (mintConfirmed && mintToastId.current) {
      updateToast(mintToastId.current, 'confirmed', 'Minted successfully!')
      mintToastId.current = null
    }
  }, [mintConfirmed, updateToast])

  // Effect 6 — toast: either write error or receipt error
  useEffect(() => {
    const err = mintWriteError ?? mintReceiptError
    if (!err) return
    const msg = `Transaction failed: ${parseRevertReason(err)}`
    if (mintToastId.current) {
      updateToast(mintToastId.current, 'failed', msg)
      mintToastId.current = null
    } else {
      addToast('failed', msg)
    }
  }, [mintWriteError, mintReceiptError, addToast, updateToast])

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!isConnected || !address) return
    let amount: bigint
    try {
      amount = parseUnits(amountStr, 6)
    } catch {
      return
    }
    if (amount <= 0n) return
    setFormState('pending')
    mintWrite({
      address: TOKEN_ADDRESS,
      abi: mockStablecoinAbi,
      functionName: 'mint',
      args: [address, amount],
    })
  }

  function handleReset() {
    resetMintWrite()
    setFormState('idle')
    mintToastId.current = null
  }

  const isDisabled = !isConnected || formState !== 'idle'

  const submitLabel =
    formState === 'idle'
      ? 'Mint'
      : formState === 'pending'
        ? 'Minting...'
        : formState === 'done'
          ? 'Done!'
          : 'Error — try again'

  const formattedBalance =
    balance !== undefined
      ? formatUnits(balance as bigint, 6) + ' mUSDC'
      : isConnected
        ? 'Loading...'
        : '—'

  const displayError = mintWriteError ?? mintReceiptError

  return (
    <div>
      <h1 className="text-2xl font-bold mb-2">Faucet</h1>
      <p className="text-sm text-yellow-600 mb-2">
        This is testnet mUSDC — no real value.
      </p>
      <p className="mb-4">
        Balance: <span className="font-mono">{formattedBalance}</span>
      </p>

      {!isConnected && (
        <div className="mb-6 p-4 border rounded">
          <p className="mb-3">Connect your wallet to mint mUSDC.</p>
          <ConnectWallet />
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-4 w-full max-w-md mt-4">
        <div>
          <label htmlFor="amountStr" className="block mb-1 text-sm font-medium">
            Amount (mUSDC)
          </label>
          <input
            id="amountStr"
            value={amountStr}
            onChange={(e) => setAmountStr(e.target.value)}
            disabled={isDisabled}
            className="w-full border rounded px-3 py-2 font-mono disabled:opacity-50"
          />
        </div>
        <button
          type="submit"
          disabled={isDisabled}
          className="px-4 py-2 bg-blue-600 text-white rounded disabled:opacity-50"
        >
          {submitLabel}
        </button>
      </form>

      {formState === 'done' && (
        <div className="mt-2">
          <p className="text-green-600">Minted successfully!</p>
          <button
            onClick={handleReset}
            className="mt-2 px-3 py-1 border rounded text-sm"
          >
            Mint again
          </button>
        </div>
      )}

      {formState === 'error' && (
        <div className="mt-2">
          <p className="text-red-500">Error: {parseRevertReason(displayError)}</p>
          <button
            onClick={handleReset}
            className="mt-2 px-3 py-1 border rounded text-sm"
          >
            Reset
          </button>
        </div>
      )}
    </div>
  )
}
