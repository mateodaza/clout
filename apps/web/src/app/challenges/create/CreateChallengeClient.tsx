'use client'

import { useState, useEffect, useRef } from 'react'
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi'
import { isAddress, toHex, padHex, zeroAddress, parseUnits } from 'viem'
import { cloutEscrowAbi, mockStablecoinAbi, ESCROW_ADDRESS, TOKEN_ADDRESS } from '@/lib/contracts'
import { parseRevertReason } from '@/lib/errors'
import { useToast } from '@/contexts/ToastContext'

function validateStake(s: string): string | null {
  try {
    const amount = parseUnits(s, 6)
    if (amount <= 0n) return 'Must be a positive amount'
    return null
  } catch {
    return 'Must be a positive amount'
  }
}

export function CreateChallengeClient() {
  const { isConnected } = useAccount()
  const { addToast, updateToast } = useToast()
  const approveToastId = useRef<string | null>(null)
  const createToastId = useRef<string | null>(null)

  const [opponent, setOpponent] = useState('')
  const [stakeStr, setStakeStr] = useState('')
  const [gameDesc, setGameDesc] = useState('')
  const [resolver, setResolver] = useState('')
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [formState, setFormState] = useState<'idle' | 'approving' | 'creating' | 'done' | 'error'>('idle')
  const [pendingArgs, setPendingArgs] = useState<{
    opponent: `0x${string}`
    stakeAmount: bigint
    gameId: `0x${string}`
    designatedResolver: `0x${string}`
  } | null>(null)

  const { writeContract: approveWrite, data: approveTxHash, error: approveError } = useWriteContract()
  const { isSuccess: approveConfirmed } = useWaitForTransactionReceipt({ hash: approveTxHash })

  const { writeContract: createWrite, data: createTxHash, error: createError } = useWriteContract()
  const { isSuccess: createConfirmed } = useWaitForTransactionReceipt({ hash: createTxHash })

  // Effect 1: approve confirmed → fire createChallenge
  useEffect(() => {
    if (approveConfirmed && pendingArgs && formState === 'approving') {
      setFormState('creating')
      createWrite({
        address: ESCROW_ADDRESS,
        abi: cloutEscrowAbi,
        functionName: 'createChallenge',
        args: [
          pendingArgs.opponent,
          pendingArgs.stakeAmount,
          TOKEN_ADDRESS,
          pendingArgs.gameId,
          pendingArgs.designatedResolver,
        ],
      })
    }
  }, [approveConfirmed, pendingArgs, formState])

  // Effect 2: createChallenge confirmed → done
  useEffect(() => {
    if (createConfirmed && formState === 'creating') {
      setFormState('done')
    }
  }, [createConfirmed, formState])

  // Effect 3: any error
  useEffect(() => {
    if ((approveError || createError) && formState !== 'idle') {
      setFormState('error')
    }
  }, [approveError, createError, formState])

  // Toast effects: approve
  useEffect(() => {
    if (approveTxHash && !approveToastId.current) {
      approveToastId.current = addToast('pending', 'Token approval submitted...')
    }
  }, [approveTxHash, addToast])

  useEffect(() => {
    if (approveConfirmed && approveToastId.current) {
      updateToast(approveToastId.current, 'confirmed', 'Token approved')
      approveToastId.current = null
    }
  }, [approveConfirmed, updateToast])

  useEffect(() => {
    if (!approveError) return
    const msg = `Transaction failed: ${parseRevertReason(approveError)}`
    if (approveToastId.current) {
      updateToast(approveToastId.current, 'failed', msg)
      approveToastId.current = null
    } else {
      addToast('failed', msg)
    }
  }, [approveError, addToast, updateToast])

  // Toast effects: createChallenge
  useEffect(() => {
    if (createTxHash && !createToastId.current) {
      createToastId.current = addToast('pending', 'Transaction submitted...')
    }
  }, [createTxHash, addToast])

  useEffect(() => {
    if (createConfirmed && createToastId.current) {
      updateToast(createToastId.current, 'confirmed', 'Transaction confirmed')
      createToastId.current = null
    }
  }, [createConfirmed, updateToast])

  useEffect(() => {
    if (!createError) return
    const msg = `Transaction failed: ${parseRevertReason(createError)}`
    if (createToastId.current) {
      updateToast(createToastId.current, 'failed', msg)
      createToastId.current = null
    } else {
      addToast('failed', msg)
    }
  }, [createError, addToast, updateToast])

  function validate(): boolean {
    const errs: Record<string, string> = {}

    if (!opponent) {
      errs.opponent = 'Required'
    } else if (!isAddress(opponent)) {
      errs.opponent = 'Must be a valid address'
    } else if (opponent.toLowerCase() === zeroAddress.toLowerCase()) {
      errs.opponent = 'Opponent cannot be the zero address'
    }

    const stakeErr = validateStake(stakeStr)
    if (stakeErr) errs.stakeStr = stakeErr

    if (!gameDesc) {
      errs.gameDesc = 'Required'
    } else if (new TextEncoder().encode(gameDesc).length > 32) {
      errs.gameDesc = 'Must be 32 bytes or fewer'
    }

    if (resolver && !isAddress(resolver)) {
      errs.resolver = 'Must be a valid address'
    }

    setErrors(errs)
    return Object.keys(errs).length === 0
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!validate()) return

    const stakeAmount = parseUnits(stakeStr, 6) // exact — no float
    const gameId = padHex(toHex(gameDesc), { size: 32, dir: 'right' })
    const designatedResolver =
      resolver && isAddress(resolver)
        ? (resolver as `0x${string}`)
        : zeroAddress

    setPendingArgs({ opponent: opponent as `0x${string}`, stakeAmount, gameId, designatedResolver })
    setFormState('approving')

    approveWrite({
      address: TOKEN_ADDRESS,
      abi: mockStablecoinAbi,
      functionName: 'approve',
      args: [ESCROW_ADDRESS, stakeAmount],
    })
  }

  function handleReset() {
    setFormState('idle')
    setPendingArgs(null)
    approveToastId.current = null
    createToastId.current = null
  }

  const isDisabled = formState !== 'idle'

  const submitLabel =
    formState === 'idle' ? 'Create Challenge' :
    formState === 'approving' ? 'Approving token...' :
    formState === 'creating' ? 'Creating challenge...' :
    formState === 'done' ? 'Done!' :
    'Error — try again'

  if (!isConnected) {
    return (
      <div>
        <h1>Create Challenge</h1>
        <p>Connect wallet to create a challenge.</p>
      </div>
    )
  }

  return (
    <div>
      <h1>Create Challenge</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4 w-full max-w-md mt-4">
        <div>
          <label htmlFor="opponent" className="block text-sm font-medium mb-1">Opponent address</label>
          <input
            id="opponent"
            value={opponent}
            onChange={(e) => setOpponent(e.target.value)}
            disabled={isDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {errors.opponent && <p className="text-red-500 text-sm mt-1">{errors.opponent}</p>}
        </div>

        <div>
          <label htmlFor="stakeStr" className="block text-sm font-medium mb-1">Stake amount (USDC)</label>
          <input
            id="stakeStr"
            value={stakeStr}
            onChange={(e) => setStakeStr(e.target.value)}
            placeholder="5.00"
            disabled={isDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {errors.stakeStr && <p className="text-red-500 text-sm mt-1">{errors.stakeStr}</p>}
        </div>

        <div>
          <label htmlFor="gameDesc" className="block text-sm font-medium mb-1">Game description (≤32 bytes)</label>
          <input
            id="gameDesc"
            value={gameDesc}
            onChange={(e) => setGameDesc(e.target.value)}
            placeholder="e.g. Chess match"
            disabled={isDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {errors.gameDesc && <p className="text-red-500 text-sm mt-1">{errors.gameDesc}</p>}
        </div>

        <div>
          <label htmlFor="resolver" className="block text-sm font-medium mb-1">Resolver address (optional)</label>
          <input
            id="resolver"
            value={resolver}
            onChange={(e) => setResolver(e.target.value)}
            disabled={isDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {errors.resolver && <p className="text-red-500 text-sm mt-1">{errors.resolver}</p>}
        </div>

        <button
          type="submit"
          disabled={isDisabled}
          className="w-full py-2.5 px-4 border rounded font-medium disabled:opacity-50"
        >
          {submitLabel}
        </button>
      </form>

      {formState === 'approving' && approveTxHash && (
        <p>Approve tx: {approveTxHash}</p>
      )}

      {(formState === 'creating' || formState === 'done') && createTxHash && (
        <p>Create tx: {createTxHash}</p>
      )}

      {formState === 'done' && (
        <p className="text-green-600 mt-2">Challenge created successfully!</p>
      )}

      {formState === 'error' && (
        <div className="mt-2">
          <p className="text-red-500">
            Error: {parseRevertReason(approveError ?? createError)}
          </p>
          <button onClick={handleReset} className="w-full py-2 mt-2 border rounded">Reset</button>
        </div>
      )}
    </div>
  )
}
