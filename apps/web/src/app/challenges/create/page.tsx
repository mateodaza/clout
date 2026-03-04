'use client'

import { useState, useEffect } from 'react'
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi'
import { isAddress, toHex, padHex, zeroAddress, parseUnits } from 'viem'
import { cloutEscrowAbi, mockStablecoinAbi, ESCROW_ADDRESS, TOKEN_ADDRESS } from '@/lib/contracts'

function validateStake(s: string): string | null {
  try {
    const amount = parseUnits(s, 6)
    if (amount <= 0n) return 'Must be a positive amount'
    return null
  } catch {
    return 'Must be a positive amount'
  }
}

export default function CreateChallengePage() {
  const { isConnected } = useAccount()

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
      <div style={{ padding: '1rem' }}>
        <h1>Create Challenge</h1>
        <p>Connect wallet to create a challenge.</p>
      </div>
    )
  }

  return (
    <div style={{ padding: '1rem' }}>
      <h1>Create Challenge</h1>

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem', maxWidth: '480px' }}>
        <div>
          <label htmlFor="opponent">Opponent address</label>
          <br />
          <input
            id="opponent"
            value={opponent}
            onChange={(e) => setOpponent(e.target.value)}
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.opponent && <p style={{ color: 'red' }}>{errors.opponent}</p>}
        </div>

        <div>
          <label htmlFor="stakeStr">Stake amount (USDC)</label>
          <br />
          <input
            id="stakeStr"
            value={stakeStr}
            onChange={(e) => setStakeStr(e.target.value)}
            placeholder="5.00"
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.stakeStr && <p style={{ color: 'red' }}>{errors.stakeStr}</p>}
        </div>

        <div>
          <label htmlFor="gameDesc">Game description (≤32 bytes)</label>
          <br />
          <input
            id="gameDesc"
            value={gameDesc}
            onChange={(e) => setGameDesc(e.target.value)}
            placeholder="e.g. Chess match"
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.gameDesc && <p style={{ color: 'red' }}>{errors.gameDesc}</p>}
        </div>

        <div>
          <label htmlFor="resolver">Resolver address (optional)</label>
          <br />
          <input
            id="resolver"
            value={resolver}
            onChange={(e) => setResolver(e.target.value)}
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.resolver && <p style={{ color: 'red' }}>{errors.resolver}</p>}
        </div>

        <button type="submit" disabled={isDisabled}>
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
        <p style={{ color: 'green' }}>Challenge created successfully!</p>
      )}

      {formState === 'error' && (
        <div>
          <p style={{ color: 'red' }}>
            Error: {(approveError ?? createError)?.message}
          </p>
          <button onClick={handleReset}>Reset</button>
        </div>
      )}
    </div>
  )
}
