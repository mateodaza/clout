'use client'

import { useState, useEffect, useRef } from 'react'
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi'
import { isAddress, zeroAddress, parseUnits } from 'viem'
import { cloutPoolAbi, mockStablecoinAbi, POOL_ADDRESS, TOKEN_ADDRESS } from '@/lib/contracts'
import { parseRevertReason } from '@/lib/errors'
import { useToast } from '@/contexts/ToastContext'

// Returns unix timestamp (seconds) or null if input is empty / not a valid date.
function parseDatetime(value: string): number | null {
  if (!value) return null
  const ms = new Date(value).getTime()
  if (isNaN(ms)) return null
  return Math.floor(ms / 1000)
}

export default function CreatePoolPage() {
  const { isConnected, address } = useAccount()
  const { addToast, updateToast } = useToast()
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

  const { writeContract: approveWrite, data: approveTxHash, error: approveError, reset: approveReset } = useWriteContract()
  const { isSuccess: approveConfirmed } = useWaitForTransactionReceipt({ hash: approveTxHash })

  const { writeContract: createWrite, data: createTxHash, error: createError, reset: createReset } = useWriteContract()
  const { isSuccess: createConfirmed } = useWaitForTransactionReceipt({ hash: createTxHash })

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

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
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
    setFormState('approving')

    approveWrite({
      address: TOKEN_ADDRESS,
      abi: mockStablecoinAbi,
      functionName: 'approve',
      args: [POOL_ADDRESS, args.initialYesStake],
    })
  }

  function handleReset() {
    setFormState('idle')
    setPendingArgs(null)
    approveReset()
    createReset()
    approveToastId.current = null
    createToastId.current = null
  }

  const isDisabled = formState !== 'idle'

  const submitLabel =
    formState === 'idle' ? 'Create Pool' :
    formState === 'approving' ? 'Approving token...' :
    formState === 'creating' ? 'Creating pool...' :
    formState === 'done' ? 'Done!' :
    'Error — try again'

  if (!isConnected) {
    return (
      <div style={{ padding: '1rem' }}>
        <h1>Create Pool</h1>
        <p>Connect wallet to create a pool.</p>
      </div>
    )
  }

  return (
    <div style={{ padding: '1rem' }}>
      <h1>Create Pool</h1>

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem', maxWidth: '480px' }}>
        <div>
          <label htmlFor="eventDescription">Event description</label>
          <br />
          <input
            id="eventDescription"
            value={eventDescription}
            onChange={(e) => setEventDescription(e.target.value)}
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
        </div>

        <div>
          <label htmlFor="eventStart">Event start</label>
          <br />
          <input
            id="eventStart"
            type="datetime-local"
            value={eventStart}
            onChange={(e) => setEventStart(e.target.value)}
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.eventStart && <p style={{ color: 'red' }}>{errors.eventStart}</p>}
        </div>

        <div>
          <label htmlFor="eventEnd">Event end</label>
          <br />
          <input
            id="eventEnd"
            type="datetime-local"
            value={eventEnd}
            onChange={(e) => setEventEnd(e.target.value)}
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.eventEnd && <p style={{ color: 'red' }}>{errors.eventEnd}</p>}
        </div>

        <div>
          <label htmlFor="resolveBy">Resolve by</label>
          <br />
          <input
            id="resolveBy"
            type="datetime-local"
            value={resolveBy}
            onChange={(e) => setResolveBy(e.target.value)}
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.resolveBy && <p style={{ color: 'red' }}>{errors.resolveBy}</p>}
        </div>

        <div>
          <label htmlFor="resolver">Resolver address</label>
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

        <div>
          <label htmlFor="perWalletCapStr">Per-wallet cap (USDC)</label>
          <br />
          <input
            id="perWalletCapStr"
            value={perWalletCapStr}
            onChange={(e) => setPerWalletCapStr(e.target.value)}
            placeholder="100.00"
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.perWalletCapStr && <p style={{ color: 'red' }}>{errors.perWalletCapStr}</p>}
        </div>

        <div>
          <label htmlFor="totalPoolCapStr">Total pool cap (USDC)</label>
          <br />
          <input
            id="totalPoolCapStr"
            value={totalPoolCapStr}
            onChange={(e) => setTotalPoolCapStr(e.target.value)}
            placeholder="10000.00"
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.totalPoolCapStr && <p style={{ color: 'red' }}>{errors.totalPoolCapStr}</p>}
        </div>

        <div>
          <label htmlFor="commissionBpsStr">Host commission (bps, 0–10000)</label>
          <br />
          <input
            id="commissionBpsStr"
            type="number"
            value={commissionBpsStr}
            onChange={(e) => setCommissionBpsStr(e.target.value)}
            placeholder="100"
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.commissionBpsStr && <p style={{ color: 'red' }}>{errors.commissionBpsStr}</p>}
        </div>

        <div>
          <label htmlFor="initialYesStakeStr">Initial YES stake (USDC)</label>
          <br />
          <input
            id="initialYesStakeStr"
            value={initialYesStakeStr}
            onChange={(e) => setInitialYesStakeStr(e.target.value)}
            placeholder="1.00"
            disabled={isDisabled}
            style={{ width: '100%' }}
          />
          {errors.initialYesStakeStr && <p style={{ color: 'red' }}>{errors.initialYesStakeStr}</p>}
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
        <p style={{ color: 'green' }}>Pool created successfully!</p>
      )}

      {formState === 'error' && (
        <div>
          <p style={{ color: 'red' }}>
            Error: {parseRevertReason(approveError ?? createError)}
          </p>
          <button onClick={handleReset}>Reset</button>
        </div>
      )}
    </div>
  )
}
