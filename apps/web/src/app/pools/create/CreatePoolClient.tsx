'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import { useWriteContract, useWaitForTransactionReceipt, useAccount, useReadContract, useEstimateGas, useGasPrice } from 'wagmi'
import { isAddress, zeroAddress, parseUnits, formatUnits, encodeFunctionData } from 'viem'
import { cloutPoolAbi, mockStablecoinAbi, POOL_ADDRESS, TOKEN_ADDRESS } from '@/lib/contracts'
import { parseRevertReason } from '@/lib/errors'
import { useToast } from '@/contexts/ToastContext'
import { ConnectWallet } from '@/components/ConnectWallet'
import { useTokenBalance } from '@/lib/useTokenBalance'
import { formatBalance, basescanUrl } from '@/lib/utils'
import { useWrongChain } from '@/lib/useWrongChain'

// Returns unix timestamp (seconds) or null if input is empty / not a valid date.
function parseDatetime(value: string): number | null {
  if (!value) return null
  const ms = new Date(value).getTime()
  if (isNaN(ms)) return null
  return Math.floor(ms / 1000)
}

export function CreatePoolClient() {
  const { isConnected, address } = useAccount()
  const isWrongChain = useWrongChain()
  const { addToast, updateToast } = useToast()
  const { data: balance, refetch: refetchBalance } = useTokenBalance()
  const approveToastId = useRef<string | null>(null)
  const createToastId = useRef<string | null>(null)

  const [eventDescription, setEventDescription] = useState('')
  const [eventStart, setEventStart] = useState('')
  const [eventEnd, setEventEnd] = useState('')
  const [resolveBy, setResolveBy] = useState('')
  const [resolver, setResolver] = useState('')
  const [perWalletCapStr, setPerWalletCapStr] = useState('')
  const [totalPoolCapStr, setTotalPoolCapStr] = useState('')
  const [commissionBpsStr, setCommissionBpsStr] = useState('')
  const [initialYesStakeStr, setInitialYesStakeStr] = useState('')

  const [errors, setErrors] = useState<Record<string, string>>({})
  const [formState, setFormState] = useState<'idle' | 'approving' | 'creating' | 'done' | 'error'>('idle')
  const [pendingArgs, setPendingArgs] = useState<{
    resolver: `0x${string}`
    eventStart: bigint
    eventEnd: bigint
    resolveBy: bigint
    perWalletCap: bigint
    totalPoolCap: bigint
    hostCommissionBps: bigint
    initialYesStake: bigint
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
    args: [address ?? zeroAddress, POOL_ADDRESS],
    query: { enabled: isConnected && !!address },
  })

  const stakeAmount = useMemo(() => {
    try { return parseUnits(initialYesStakeStr, 6) } catch { return 0n }
  }, [initialYesStakeStr])

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
    isConnected &&
    stakeAmount > 0n &&
    parseDatetime(eventStart) !== null &&
    parseDatetime(eventEnd) !== null &&
    parseDatetime(resolveBy) !== null &&
    isAddress(resolver)

  const callData = useMemo(() => {
    if (!estimateReady) return undefined
    try {
      const eventStartUnix = parseDatetime(eventStart)!
      const eventEndUnix = parseDatetime(eventEnd)!
      const resolveByUnix = parseDatetime(resolveBy)!
      return encodeFunctionData({
        abi: cloutPoolAbi,
        functionName: 'createPool',
        args: [
          resolver as `0x${string}`,
          TOKEN_ADDRESS,
          BigInt(eventStartUnix),
          BigInt(eventEndUnix),
          BigInt(resolveByUnix),
          parseUnits(perWalletCapStr || '0', 6),
          parseUnits(totalPoolCapStr || '0', 6),
          BigInt(Number(commissionBpsStr.trim() || '0')),
          stakeAmount,
        ],
      })
    } catch { return undefined }
  }, [estimateReady, resolver, eventStart, eventEnd, resolveBy, perWalletCapStr, totalPoolCapStr, commissionBpsStr, stakeAmount])

  const { data: gasUnits } = useEstimateGas({
    to: POOL_ADDRESS,
    data: callData,
    query: { enabled: !!callData },
  })
  const { data: gasPrice } = useGasPrice()
  const gasCostWei =
    gasUnits !== undefined && gasPrice !== undefined ? gasUnits * gasPrice : undefined

  // Effect 1: approve confirmed → fire createPool
  useEffect(() => {
    if (approveConfirmed && pendingArgs && formState === 'approving') {
      setFormState('creating')
      createWrite({
        address: POOL_ADDRESS,
        abi: cloutPoolAbi,
        functionName: 'createPool',
        args: [
          pendingArgs.resolver,          // address resolver
          TOKEN_ADDRESS,                  // address token
          pendingArgs.eventStart,         // uint256 eventStart
          pendingArgs.eventEnd,           // uint256 eventEnd
          pendingArgs.resolveBy,          // uint256 resolveBy
          pendingArgs.perWalletCap,       // uint256 perWalletCap
          pendingArgs.totalPoolCap,       // uint256 totalPoolCap
          pendingArgs.hostCommissionBps,  // uint256 hostCommissionBps
          pendingArgs.initialYesStake,    // uint256 initialYesStake
        ],
      })
    }
  }, [approveConfirmed, pendingArgs, formState])

  // Effect 2: createPool confirmed → done
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

  // Toast effects — approve
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

  // Toast effects — createPool
  useEffect(() => {
    if (createTxHash && !createToastId.current) {
      createToastId.current = addToast('pending', 'Transaction submitted...')
    }
  }, [createTxHash, addToast])

  useEffect(() => {
    if (createConfirmed && createToastId.current) {
      updateToast(createToastId.current, 'confirmed', 'Pool created!')
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
    const now = Math.floor(Date.now() / 1000)

    const eventStartUnix = parseDatetime(eventStart)
    const eventEndUnix = parseDatetime(eventEnd)
    const resolveByUnix = parseDatetime(resolveBy)

    // Step 1: null checks
    if (eventStartUnix === null) errs.eventStart = 'Required'
    if (eventEndUnix === null) errs.eventEnd = 'Required'
    if (resolveByUnix === null) errs.resolveBy = 'Required'

    // Step 2: ordering checks (only when both sides are non-null)
    if (eventStartUnix !== null && eventStartUnix <= now) {
      errs.eventStart = 'Must be in the future'
    }
    if (eventStartUnix !== null && eventEndUnix !== null && eventEndUnix <= eventStartUnix) {
      errs.eventEnd = 'Must be after eventStart'
    }
    if (eventEndUnix !== null && resolveByUnix !== null && resolveByUnix <= eventEndUnix) {
      errs.resolveBy = 'Must be after eventEnd'
    }

    // Step 3: resolver (required — contract reverts on zero address or resolver == host)
    if (!resolver) {
      errs.resolver = 'Required'
    } else if (!isAddress(resolver)) {
      errs.resolver = 'Must be a valid address'
    } else if (resolver === zeroAddress) {
      errs.resolver = 'Cannot be the zero address'
    } else if (address && resolver.toLowerCase() === address.toLowerCase()) {
      errs.resolver = 'Cannot be the host address'
    }

    // Step 4: amounts (track parsed values for cross-field checks)
    let perWalletCapParsed: bigint | null = null
    let totalPoolCapParsed: bigint | null = null
    let initialYesStakeParsed: bigint | null = null

    try {
      perWalletCapParsed = parseUnits(perWalletCapStr, 6)
      if (perWalletCapParsed <= 0n) { errs.perWalletCapStr = 'Must be > 0'; perWalletCapParsed = null }
    } catch {
      errs.perWalletCapStr = 'Must be > 0'
    }
    try {
      totalPoolCapParsed = parseUnits(totalPoolCapStr, 6)
      if (totalPoolCapParsed <= 0n) { errs.totalPoolCapStr = 'Must be > 0'; totalPoolCapParsed = null }
    } catch {
      errs.totalPoolCapStr = 'Must be > 0'
    }
    try {
      initialYesStakeParsed = parseUnits(initialYesStakeStr, 6)
      if (initialYesStakeParsed <= 0n) { errs.initialYesStakeStr = 'Must be > 0'; initialYesStakeParsed = null }
    } catch {
      errs.initialYesStakeStr = 'Must be > 0'
    }

    // Cross-field cap checks (only when all relevant amounts parsed successfully)
    if (initialYesStakeParsed !== null && perWalletCapParsed !== null && initialYesStakeParsed > perWalletCapParsed) {
      errs.initialYesStakeStr = 'Must not exceed per-wallet cap'
    }
    if (initialYesStakeParsed !== null && totalPoolCapParsed !== null && initialYesStakeParsed > totalPoolCapParsed) {
      errs.initialYesStakeStr = 'Must not exceed total pool cap'
    }

    // Step 5: commission bps — reject decimals and scientific notation
    if (!/^\d+$/.test(commissionBpsStr.trim())) {
      errs.commissionBpsStr = 'Must be 0–10000'
    } else {
      const bps = Number(commissionBpsStr.trim())
      if (bps < 0 || bps > 10000) {
        errs.commissionBpsStr = 'Must be 0–10000'
      }
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

    // parseDatetime is guaranteed non-null here because validate() would have returned false otherwise
    const eventStartUnix = parseDatetime(eventStart)!
    const eventEndUnix = parseDatetime(eventEnd)!
    const resolveByUnix = parseDatetime(resolveBy)!

    const args = {
      resolver: resolver as `0x${string}`,
      eventStart: BigInt(eventStartUnix),
      eventEnd: BigInt(eventEndUnix),
      resolveBy: BigInt(resolveByUnix),
      perWalletCap: parseUnits(perWalletCapStr, 6),
      totalPoolCap: parseUnits(totalPoolCapStr, 6),
      hostCommissionBps: BigInt(Number(commissionBpsStr.trim())),
      initialYesStake: parseUnits(initialYesStakeStr, 6),
    }

    setPendingArgs(args)

    if (allowanceData !== undefined && (allowanceData as bigint) >= args.initialYesStake) {
      // Sufficient allowance — skip approve, go directly to create
      setFormState('creating')
      createWrite({
        address: POOL_ADDRESS,
        abi: cloutPoolAbi,
        functionName: 'createPool',
        args: [
          args.resolver,
          TOKEN_ADDRESS,
          args.eventStart,
          args.eventEnd,
          args.resolveBy,
          args.perWalletCap,
          args.totalPoolCap,
          args.hostCommissionBps,
          args.initialYesStake,
        ],
      })
    } else {
      setFormState('approving')
      approveWrite({
        address: TOKEN_ADDRESS,
        abi: mockStablecoinAbi,
        functionName: 'approve',
        args: [POOL_ADDRESS, args.initialYesStake],
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

  const isInputDisabled = !isConnected || formState !== 'idle' || isWrongChain
  const isSubmitDisabled = isInputDisabled || isBalanceInsufficient

  const submitLabel =
    formState === 'idle' ? 'Create Pool' :
    formState === 'approving' ? 'Approving token...' :
    formState === 'creating' ? 'Creating pool...' :
    formState === 'done' ? 'Done!' :
    'Error — try again'

  return (
    <div>
      <h1>Create Pool</h1>

      {!isConnected && (
        <div className="mb-6 p-4 border rounded">
          <p className="mb-3">Connect your wallet to create a pool.</p>
          <ConnectWallet />
        </div>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-4 w-full max-w-md mt-4">
        <div>
          <label htmlFor="eventDescription" className="block text-sm font-medium mb-1">Event description</label>
          <input
            id="eventDescription"
            value={eventDescription}
            onChange={(e) => { setEventDescription(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, eventDescription: true })); validate() }}
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
        </div>

        <div>
          <label htmlFor="eventStart" className="block text-sm font-medium mb-1">Event start</label>
          <input
            id="eventStart"
            type="datetime-local"
            value={eventStart}
            onChange={(e) => { setEventStart(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, eventStart: true })); validate() }}
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.eventStart || hasSubmitted) && errors.eventStart && (
            <p className="text-red-500 text-sm mt-1">{errors.eventStart}</p>
          )}
        </div>

        <div>
          <label htmlFor="eventEnd" className="block text-sm font-medium mb-1">Event end</label>
          <input
            id="eventEnd"
            type="datetime-local"
            value={eventEnd}
            onChange={(e) => { setEventEnd(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, eventEnd: true })); validate() }}
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.eventEnd || hasSubmitted) && errors.eventEnd && (
            <p className="text-red-500 text-sm mt-1">{errors.eventEnd}</p>
          )}
        </div>

        <div>
          <label htmlFor="resolveBy" className="block text-sm font-medium mb-1">Resolve by</label>
          <input
            id="resolveBy"
            type="datetime-local"
            value={resolveBy}
            onChange={(e) => { setResolveBy(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, resolveBy: true })); validate() }}
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.resolveBy || hasSubmitted) && errors.resolveBy && (
            <p className="text-red-500 text-sm mt-1">{errors.resolveBy}</p>
          )}
        </div>

        <div>
          <label htmlFor="resolver" className="block text-sm font-medium mb-1">Resolver address</label>
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

        <div>
          <label htmlFor="perWalletCapStr" className="block text-sm font-medium mb-1">Per-wallet cap (USDC)</label>
          <input
            id="perWalletCapStr"
            value={perWalletCapStr}
            onChange={(e) => { setPerWalletCapStr(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, perWalletCapStr: true })); validate() }}
            placeholder="100.00"
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.perWalletCapStr || hasSubmitted) && errors.perWalletCapStr && (
            <p className="text-red-500 text-sm mt-1">{errors.perWalletCapStr}</p>
          )}
        </div>

        <div>
          <label htmlFor="totalPoolCapStr" className="block text-sm font-medium mb-1">Total pool cap (USDC)</label>
          <input
            id="totalPoolCapStr"
            value={totalPoolCapStr}
            onChange={(e) => { setTotalPoolCapStr(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, totalPoolCapStr: true })); validate() }}
            placeholder="10000.00"
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.totalPoolCapStr || hasSubmitted) && errors.totalPoolCapStr && (
            <p className="text-red-500 text-sm mt-1">{errors.totalPoolCapStr}</p>
          )}
        </div>

        <div>
          <label htmlFor="commissionBpsStr" className="block text-sm font-medium mb-1">Host commission (bps, 0–10000)</label>
          <input
            id="commissionBpsStr"
            type="number"
            value={commissionBpsStr}
            onChange={(e) => { setCommissionBpsStr(e.target.value); scheduleValidate() }}
            onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, commissionBpsStr: true })); validate() }}
            placeholder="100"
            disabled={isInputDisabled}
            className="w-full border rounded px-3 py-2 text-sm"
          />
          {(touched.commissionBpsStr || hasSubmitted) && errors.commissionBpsStr && (
            <p className="text-red-500 text-sm mt-1">{errors.commissionBpsStr}</p>
          )}
        </div>

        {isConnected && (
          <p className="text-sm text-gray-500">
            Your balance: {balance !== undefined ? formatBalance(balance as bigint) : '—'}
          </p>
        )}

        <div>
          <label htmlFor="initialYesStakeStr" className="block text-sm font-medium mb-1">Initial YES stake (USDC)</label>
          <div className="flex gap-2">
            <input
              id="initialYesStakeStr"
              value={initialYesStakeStr}
              onChange={(e) => { setInitialYesStakeStr(e.target.value); scheduleValidate() }}
              onBlur={() => { clearTimeout(debounceRef.current!); setTouched(t => ({ ...t, initialYesStakeStr: true })); validate() }}
              placeholder="1.00"
              disabled={isInputDisabled}
              className="w-full border rounded px-3 py-2 text-sm"
            />
            {isConnected && balance !== undefined && (balance as bigint) > 0n && (
              <button
                type="button"
                onClick={() => setInitialYesStakeStr(formatUnits(balance as bigint, 6))}
                disabled={!isConnected || formState !== 'idle' || isWrongChain}
                className="px-3 py-2 border rounded text-sm whitespace-nowrap disabled:opacity-50"
              >Max</button>
            )}
          </div>
          {(touched.initialYesStakeStr || hasSubmitted) && errors.initialYesStakeStr && (
            <p className="text-red-500 text-sm mt-1">{errors.initialYesStakeStr}</p>
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
        <p>
          Approve tx:{' '}
          <a href={basescanUrl('tx', approveTxHash)} target="_blank" rel="noopener">
            {`${approveTxHash.slice(0, 10)}…${approveTxHash.slice(-8)}`}
          </a>
        </p>
      )}

      {(formState === 'creating' || formState === 'done') && createTxHash && (
        <p>
          Create tx:{' '}
          <a href={basescanUrl('tx', createTxHash)} target="_blank" rel="noopener">
            {`${createTxHash.slice(0, 10)}…${createTxHash.slice(-8)}`}
          </a>
        </p>
      )}

      {formState === 'done' && (
        <p className="text-green-600 mt-2">Pool created successfully!</p>
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
