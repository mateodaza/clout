'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import { useWriteContract, useWaitForTransactionReceipt, useAccount, useReadContract, useEstimateGas, useGasPrice } from 'wagmi'
import { isAddress, toHex, padHex, zeroAddress, parseUnits, formatUnits, encodeFunctionData } from 'viem'
import { cloutEscrowAbi, mockStablecoinAbi, ESCROW_ADDRESS, TOKEN_ADDRESS } from '@/lib/contracts'
import { parseRevertReason } from '@/lib/errors'
import { useToast } from '@/contexts/ToastContext'
import { ConnectWallet } from '@/components/ConnectWallet'
import { useTokenBalance } from '@/lib/useTokenBalance'
import { formatBalance } from '@/lib/utils'

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
  const { isConnected, address } = useAccount()
  const { addToast, updateToast } = useToast()
  const { data: balance, refetch: refetchBalance } = useTokenBalance()
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
  const [touched, setTouched] = useState<Record<string, boolean>>({})
  const [hasSubmitted, setHasSubmitted] = useState(false)
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const { writeContract: approveWrite, data: approveTxHash, error: approveError, reset: approveReset } = useWriteContract()
  const { isSuccess: approveConfirmed } = useWaitForTransactionReceipt({ hash: approveTxHash })

  const { writeContract: createWrite, data: createTxHash, error: createError, reset: createReset } = useWriteContract()
  const { isSuccess: createConfirmed } = useWaitForTransactionReceipt({ hash: createTxHash })

  const { data: allowanceData } = useReadContract({
    address: TOKEN_ADDRESS,
    abi: mockStablecoinAbi,
    functionName: 'allowance',
    args: [address ?? zeroAddress, ESCROW_ADDRESS],
    query: { enabled: isConnected && !!address },
  })

  const stakeAmount = useMemo(() => {
    try { return parseUnits(stakeStr, 6) } catch { return 0n }
  }, [stakeStr])

  const isBalanceInsufficient =
    isConnected &&
    balance !== undefined &&
    stakeAmount > 0n &&
    (balance as bigint) < stakeAmount

  const isAllowanceSufficient =
    allowanceData !== undefined &&
    (allowanceData as bigint) >= stakeAmount &&
    stakeAmount > 0n

  const estimateReady =
    isConnected && isAddress(opponent) && stakeAmount > 0n && gameDesc.length > 0

  const callData = useMemo(() => {
    if (!estimateReady) return undefined
    try {
      const gameId = padHex(toHex(gameDesc), { size: 32, dir: 'right' })
      const resolverAddr =
        resolver && isAddress(resolver) ? (resolver as `0x${string}`) : zeroAddress
      return encodeFunctionData({
        abi: cloutEscrowAbi,
        functionName: 'createChallenge',
        args: [opponent as `0x${string}`, stakeAmount, TOKEN_ADDRESS, gameId, resolverAddr],
      })
    } catch { return undefined }
  }, [estimateReady, opponent, stakeAmount, gameDesc, resolver])

  const { data: gasUnits } = useEstimateGas({
    to: ESCROW_ADDRESS,
    data: callData,
    query: { enabled: !!callData },
  })
  const { data: gasPrice } = useGasPrice()
  const gasCostWei =
    gasUnits !== undefined && gasPrice !== undefined ? gasUnits * gasPrice : undefined

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
      void refetchBalance()
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

  // Cleanup debounce on unmount
  useEffect(() => () => { if (debounceRef.current) clearTimeout(debounceRef.current) }, [])

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

  function scheduleValidate() {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => validate(), 500)
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setHasSubmitted(true)
    if (!validate()) return

    const stakeAmt = parseUnits(stakeStr, 6)
    const gameId = padHex(toHex(gameDesc), { size: 32, dir: 'right' })
    const designatedResolver =
      resolver && isAddress(resolver) ? (resolver as `0x${string}`) : zeroAddress

    const args = {
      opponent: opponent as `0x${string}`,
      stakeAmount: stakeAmt,
      gameId,
      designatedResolver,
    }
    setPendingArgs(args)

    if (allowanceData !== undefined && (allowanceData as bigint) >= stakeAmt) {
      // Sufficient allowance — skip approve, go directly to create
      setFormState('creating')
      createWrite({
        address: ESCROW_ADDRESS,
        abi: cloutEscrowAbi,
        functionName: 'createChallenge',
        args: [args.opponent, args.stakeAmount, TOKEN_ADDRESS, args.gameId, args.designatedResolver],
      })
    } else {
      setFormState('approving')
      approveWrite({
        address: TOKEN_ADDRESS,
        abi: mockStablecoinAbi,
        functionName: 'approve',
        args: [ESCROW_ADDRESS, stakeAmt],
      })
    }
  }

  function handleReset() {
    setFormState('idle')
    setPendingArgs(null)
    setTouched({})
    setHasSubmitted(false)
    if (debounceRef.current) clearTimeout(debounceRef.current)
    approveReset()
    createReset()
    approveToastId.current = null
    createToastId.current = null
  }

  const isInputDisabled = !isConnected || formState !== 'idle'
  const isSubmitDisabled = isInputDisabled || isBalanceInsufficient

  const submitLabel =
    formState === 'idle' ? 'Create Challenge' :
    formState === 'approving' ? 'Approving token...' :
    formState === 'creating' ? 'Creating challenge...' :
    formState === 'done' ? 'Done!' :
    'Error — try again'

  return (
    <div>
      <h1>Create Challenge</h1>

      {!isConnected && (
        <div className="mb-6 p-4 border rounded">
          <p className="mb-3">Connect your wallet to create a challenge.</p>
          <ConnectWallet />
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-4 w-full max-w-md mt-4">
        <div>
          <label htmlFor="opponent" className="block text-sm font-medium mb-1">Opponent address</label>
          <input
            id="opponent"
            value={opponent}
            onChange={(e) => { setOpponent(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, opponent: true })); validate() }}
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.opponent || hasSubmitted) && errors.opponent && (
            <p className="text-red-500 text-sm mt-1">{errors.opponent}</p>
          )}
        </div>

        {isConnected && (
          <p className="text-sm text-gray-500">
            Your balance: {balance !== undefined ? formatBalance(balance as bigint) : '—'}
          </p>
        )}

        <div>
          <label htmlFor="stakeStr" className="block text-sm font-medium mb-1">Stake amount (USDC)</label>
          <div className="flex gap-2">
            <input
              id="stakeStr"
              value={stakeStr}
              onChange={(e) => { setStakeStr(e.target.value); scheduleValidate() }}
              onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, stakeStr: true })); validate() }}
              placeholder="5.00"
              disabled={isInputDisabled}
              className="w-full border rounded px-3 py-2 text-sm"
            />
            {isConnected && balance !== undefined && (balance as bigint) > 0n && (
              <button
                type="button"
                onClick={() => setStakeStr(formatUnits(balance as bigint, 6))}
                disabled={!isConnected || formState !== 'idle'}
                className="px-3 py-2 border rounded text-sm whitespace-nowrap disabled:opacity-50"
              >Max</button>
            )}
          </div>
          {(touched.stakeStr || hasSubmitted) && errors.stakeStr && (
            <p className="text-red-500 text-sm mt-1">{errors.stakeStr}</p>
          )}
          {isBalanceInsufficient && (
            <p className="text-amber-600 text-sm mt-1">
              Insufficient balance — you have {formatBalance(balance as bigint)}
            </p>
          )}
        </div>

        {isConnected && stakeAmount > 0n && (
          <p className="text-sm text-gray-500">
            {isAllowanceSufficient
              ? '✓ Sufficient allowance — approve step will be skipped'
              : 'Approval required before creating'}
          </p>
        )}

        <div>
          <label htmlFor="gameDesc" className="block text-sm font-medium mb-1">Game description (≤32 bytes)</label>
          <input
            id="gameDesc"
            value={gameDesc}
            onChange={(e) => { setGameDesc(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, gameDesc: true })); validate() }}
            placeholder="e.g. Chess match"
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.gameDesc || hasSubmitted) && errors.gameDesc && (
            <p className="text-red-500 text-sm mt-1">{errors.gameDesc}</p>
          )}
        </div>

        <div>
          <label htmlFor="resolver" className="block text-sm font-medium mb-1">Resolver address (optional)</label>
          <input
            id="resolver"
            value={resolver}
            onChange={(e) => { setResolver(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, resolver: true })); validate() }}
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.resolver || hasSubmitted) && errors.resolver && (
            <p className="text-red-500 text-sm mt-1">{errors.resolver}</p>
          )}
        </div>

        <button
          type="submit"
          disabled={isSubmitDisabled}
          className="w-full py-2.5 px-4 border rounded font-medium disabled:opacity-50"
        >
          {submitLabel}
        </button>

        {gasCostWei !== undefined && (
          <p className="text-xs text-gray-400 mt-1">
            Est. gas: ~{formatUnits(gasCostWei, 18).slice(0, 8)} ETH
          </p>
        )}
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
