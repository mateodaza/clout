'use client'

import { use, useState, useEffect, useRef } from 'react'
import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useAccount,
} from 'wagmi'
import { parseUnits, zeroAddress } from 'viem'
import { PoolState } from '@clout/types'
import {
  cloutPoolAbi,
  mockStablecoinAbi,
  POOL_ADDRESS,
} from '@/lib/contracts'
import Link from 'next/link'
import { Skeleton } from '@/components/Skeleton'
import { PoolStateBadge } from '@/components/StateBadge'
import { parseRevertReason } from '@/lib/errors'
import { useToast } from '@/contexts/ToastContext'

// ─── Local Types ────────────────────────────────────────────────────────────

interface ParsedPool {
  host: `0x${string}`
  resolver: `0x${string}`
  token: `0x${string}`
  eventStart: bigint
  eventEnd: bigint
  resolveBy: bigint
  perWalletCap: bigint
  totalPoolCap: bigint
  hostCommissionBps: bigint
  state: number
  yesTotal: bigint
  noTotal: bigint
  resolvedAt: bigint
  yesWins: boolean
  losingStakerCount: bigint
  flagCount: bigint
}

type ActionState =
  | 'idle'
  | 'approving'
  | 'staking'
  | 'closing'
  | 'resolving'
  | 'flagging'
  | 'finalizing'
  | 'voiding'
  | 'claiming'
  | 'adminResolving'
  | 'done'
  | 'error'

// ─── Helpers ─────────────────────────────────────────────────────────────────

function tryParseAmount(str: string): bigint | null {
  try {
    const v = parseUnits(str.trim(), 6)
    return v > 0n ? v : null
  } catch {
    return null
  }
}

function formatUsdc(amount: bigint): string {
  return (Number(amount) / 1_000_000).toFixed(2) + ' USDC'
}

function formatTs(ts: bigint): string {
  return ts === 0n ? '—' : new Date(Number(ts) * 1000).toLocaleString()
}

function truncateAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}


// ─── Page ─────────────────────────────────────────────────────────────────────

export function PoolDetailClient({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const isValidId = /^\d+$/.test(id)
  const poolId = isValidId ? BigInt(id) : 0n

  // ── Wallet ──
  const { address: connectedAddress, isConnected } = useAccount()
  const { addToast, updateToast } = useToast()
  const approveToastId = useRef<string | null>(null)
  const mainToastId = useRef<string | null>(null)

  // ── Read: pool ──
  const { data: poolData, isLoading: poolLoading, refetch: refetchPool } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'getPool',
    args: [poolId],
    query: { enabled: isValidId },
  })

  // ── Read: user stakes ──
  const { data: stakesData, refetch: refetchStakes } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'getStakes',
    args: [poolId, connectedAddress ?? zeroAddress],
    query: { enabled: isValidId && !!connectedAddress },
  })

  // ── Read: staker counts ──
  const { data: stakerCountsData } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'getStakerCounts',
    args: [poolId],
    query: { enabled: isValidId },
  })

  // ── Read: host's stakes (for canVoidFromOpen — noStakes[poolId][pool.host]) ──
  const { data: hostStakesData } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'getStakes',
    args: [poolId, (poolData as ParsedPool | undefined)?.host ?? zeroAddress],
    query: { enabled: isValidId && !!(poolData as ParsedPool | undefined)?.host },
  })

  // ── Read: owner ──
  const { data: ownerAddress } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'owner',
  })

  // ── Read: claimed ──
  const { data: hasClaimed } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'claimed',
    args: [poolId, connectedAddress ?? zeroAddress],
    query: { enabled: isValidId && !!connectedAddress },
  })

  // ── Read: dispute flag ──
  const { data: alreadyFlagged } = useReadContract({
    address: POOL_ADDRESS,
    abi: cloutPoolAbi,
    functionName: 'disputeFlags',
    args: [poolId, connectedAddress ?? zeroAddress],
    query: { enabled: isValidId && !!connectedAddress },
  })

  // ── Write: approve (for stake) ──
  const {
    writeContract: approveWrite,
    data: approveTxHash,
    error: approveError,
  } = useWriteContract()

  const { data: approveReceipt } = useWaitForTransactionReceipt({
    hash: approveTxHash,
  })
  const approveConfirmed = !!approveReceipt

  // ── Write: main actions ──
  const {
    writeContract: mainWrite,
    data: mainTxHash,
    error: mainError,
  } = useWriteContract()

  const { data: mainReceipt } = useWaitForTransactionReceipt({
    hash: mainTxHash,
  })
  const mainConfirmed = !!mainReceipt

  // ── Local state ──
  const [actionState, setActionState] = useState<ActionState>('idle')
  const [stakeAmountStr, setStakeAmountStr] = useState('')
  const [resolveYesWins, setResolveYesWins] = useState(true)
  const [pendingStake, setPendingStake] = useState<{
    isYes: boolean
    amount: bigint
    token: `0x${string}`
  } | null>(null)

  // ── Effect 1: chain approve → stakePool ──
  useEffect(() => {
    if (approveConfirmed && actionState === 'approving' && pendingStake) {
      setActionState('staking')
      mainWrite({
        address: POOL_ADDRESS,
        abi: cloutPoolAbi,
        functionName: 'stakePool',
        args: [poolId, pendingStake.isYes, pendingStake.amount],
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [approveConfirmed, actionState])

  // ── Effect 2: refetch on main tx success ──
  useEffect(() => {
    if (mainConfirmed) {
      setActionState('done')
      refetchPool()
      refetchStakes()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mainConfirmed])

  // ── Effect 3: surface errors ──
  useEffect(() => {
    if ((approveError || mainError) && actionState !== 'idle') {
      setActionState('error')
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [approveError, mainError])

  // ── Toast effects — approve ──
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

  // ── Toast effects — main tx ──
  useEffect(() => {
    if (mainTxHash && !mainToastId.current) {
      mainToastId.current = addToast('pending', 'Transaction submitted...')
    }
  }, [mainTxHash, addToast])

  useEffect(() => {
    if (mainConfirmed && mainToastId.current) {
      updateToast(mainToastId.current, 'confirmed', 'Transaction confirmed')
      mainToastId.current = null
    }
  }, [mainConfirmed, updateToast])

  useEffect(() => {
    if (!mainError) return
    const msg = `Transaction failed: ${parseRevertReason(mainError)}`
    if (mainToastId.current) {
      updateToast(mainToastId.current, 'failed', msg)
      mainToastId.current = null
    } else {
      addToast('failed', msg)
    }
  }, [mainError, addToast, updateToast])

  // ── Derived values ──
  const pool = poolData as ParsedPool | undefined
  const poolExists = isValidId && !!pool && pool.host !== zeroAddress

  const addr = connectedAddress?.toLowerCase()
  const isHost =
    !!addr && !!pool && pool.host !== zeroAddress && addr === pool.host.toLowerCase()
  const isResolver =
    !!addr && !!pool && pool.resolver !== zeroAddress && addr === pool.resolver.toLowerCase()
  const isAdmin =
    !!addr && addr === (ownerAddress as string | undefined)?.toLowerCase()

  const userYesStake: bigint = (stakesData as any)?.[0] ?? 0n
  const userNoStake: bigint = (stakesData as any)?.[1] ?? 0n
  const isStaker = userYesStake > 0n || userNoStake > 0n

  const yesCount: bigint = (stakerCountsData as any)?.[0] ?? 0n
  const noCount: bigint = (stakerCountsData as any)?.[1] ?? 0n
  // Host's NO stake — mirrors noStakes[poolId][pool.host] in the contract
  const hostNoStake: bigint = (hostStakesData as any)?.[1] ?? 0n

  // Per-wallet caps
  const yesWalletRemaining = pool
    ? pool.perWalletCap > userYesStake ? pool.perWalletCap - userYesStake : 0n
    : 0n
  const noWalletRemaining = pool
    ? pool.perWalletCap > userNoStake ? pool.perWalletCap - userNoStake : 0n
    : 0n
  // Shared total-pool cap (contract line 332: yesTotal + noTotal + amount <= totalPoolCap)
  const totalStaked = pool ? pool.yesTotal + pool.noTotal : 0n
  const totalCapRemaining = pool
    ? pool.totalPoolCap > totalStaked ? pool.totalPoolCap - totalStaked : 0n
    : 0n
  // Effective remaining = min(per-wallet remaining, total cap remaining)
  const yesRemaining = yesWalletRemaining < totalCapRemaining ? yesWalletRemaining : totalCapRemaining
  const noRemaining = noWalletRemaining < totalCapRemaining ? noWalletRemaining : totalCapRemaining

  const nowSeconds = BigInt(Math.floor(Date.now() / 1000))

  const isOnLosingSide =
    !!pool &&
    ((pool.yesWins && userNoStake > 0n) || (!pool.yesWins && userYesStake > 0n))

  const isOnWinningSide =
    !!pool &&
    ((pool.yesWins && userYesStake > 0n) || (!pool.yesWins && userNoStake > 0n))

  const DISPUTE_WINDOW_SECS = 86400n
  const withinDisputeWindow =
    !!pool && pool.resolvedAt > 0n && nowSeconds <= pool.resolvedAt + DISPUTE_WINDOW_SECS

  const canClose =
    !!pool && pool.state === PoolState.OPEN && nowSeconds >= pool.eventStart

  const canResolve =
    !!pool &&
    pool.state === PoolState.CLOSED &&
    nowSeconds >= pool.eventEnd &&
    nowSeconds <= pool.resolveBy

  const canFinalize =
    !!pool &&
    pool.state === PoolState.SUBMITTED &&
    nowSeconds > pool.resolvedAt + DISPUTE_WINDOW_SECS

  const canVoidFromClosed =
    !!pool && pool.state === PoolState.CLOSED && nowSeconds > pool.resolveBy

  // canVoidFromOpen mirrors contract lines 634–637:
  //   hostOnlyYes = yesStakerCount == 1
  //   hostOnlyNo  = noStakerCount == 0 || (noStakerCount == 1 && noStakes[poolId][pool.host] > 0)
  // voidPool is permissionless — any caller may trigger it when conditions hold
  const canVoidFromOpen =
    !!pool &&
    pool.state === PoolState.OPEN &&
    nowSeconds >= pool.eventStart &&
    yesCount === 1n &&
    (noCount === 0n || (noCount === 1n && hostNoStake > 0n))

  const inProgress =
    actionState !== 'idle' && actionState !== 'done' && actionState !== 'error'

  // ── Handlers ──
  function handleStakeYes() {
    const amount = tryParseAmount(stakeAmountStr)
    if (!amount || !pool) return
    setPendingStake({ isYes: true, amount, token: pool.token })
    setActionState('approving')
    approveWrite({
      address: pool.token,
      abi: mockStablecoinAbi,
      functionName: 'approve',
      args: [POOL_ADDRESS, amount],
    })
  }

  function handleStakeNo() {
    const amount = tryParseAmount(stakeAmountStr)
    if (!amount || !pool) return
    setPendingStake({ isYes: false, amount, token: pool.token })
    setActionState('approving')
    approveWrite({
      address: pool.token,
      abi: mockStablecoinAbi,
      functionName: 'approve',
      args: [POOL_ADDRESS, amount],
    })
  }

  function handleClosePool() {
    setActionState('closing')
    mainWrite({ address: POOL_ADDRESS, abi: cloutPoolAbi, functionName: 'closePool', args: [poolId] })
  }

  function handleResolve() {
    setActionState('resolving')
    mainWrite({ address: POOL_ADDRESS, abi: cloutPoolAbi, functionName: 'resolvePool', args: [poolId, resolveYesWins] })
  }

  function handleFlagDispute() {
    setActionState('flagging')
    mainWrite({ address: POOL_ADDRESS, abi: cloutPoolAbi, functionName: 'disputePool', args: [poolId] })
  }

  function handleFinalizePool() {
    setActionState('finalizing')
    mainWrite({ address: POOL_ADDRESS, abi: cloutPoolAbi, functionName: 'finalizePool', args: [poolId] })
  }

  function handleVoidPool() {
    setActionState('voiding')
    mainWrite({ address: POOL_ADDRESS, abi: cloutPoolAbi, functionName: 'voidPool', args: [poolId] })
  }

  function handleClaim() {
    setActionState('claiming')
    mainWrite({ address: POOL_ADDRESS, abi: cloutPoolAbi, functionName: 'claimPoolWinnings', args: [poolId] })
  }

  function handleAdminResolve() {
    setActionState('adminResolving')
    mainWrite({ address: POOL_ADDRESS, abi: cloutPoolAbi, functionName: 'adminResolvePool', args: [poolId, resolveYesWins] })
  }

  function handleReset() {
    setActionState('idle')
    approveToastId.current = null
    mainToastId.current = null
  }

  // ── Render ──
  if (!isValidId) {
    return (
      <div>
        <Link href="/pools">← Back to Pools</Link>
        <p>Invalid pool ID.</p>
      </div>
    )
  }

  return (
    <div>
      <div className="mb-4">
        <Link href="/pools">← Back to Pools</Link>
      </div>
      <h1>Pool #{id}</h1>

      {poolLoading && (
        <div className="flex flex-col gap-4 mt-4">
          <Skeleton width="6rem" height="1.75rem" />
          <div className="flex flex-col gap-3">
            {[0, 1, 2, 3, 4, 5, 6, 7].map((i) => (
              <div key={i} className="flex gap-6">
                <Skeleton width="8rem" height="1rem" className="flex-shrink-0" />
                <Skeleton width="60%" height="1rem" />
              </div>
            ))}
          </div>
        </div>
      )}

      {!poolLoading && !poolExists && <p>Pool not found.</p>}

      {poolExists && pool && (
        <>
          {/* ── Details dl grid ── */}
          <dl className="grid grid-cols-1 sm:grid-cols-[auto_1fr] gap-x-6 gap-y-1 mb-6 mt-4">
            <dt className="font-semibold py-1">State</dt>
            <dd className="py-1"><PoolStateBadge state={pool.state} /></dd>
            <dt className="font-semibold py-1">Host</dt>
            <dd className="py-1 break-all">{pool.host}</dd>
            <dt className="font-semibold py-1">Resolver</dt>
            <dd className="py-1 break-all">{pool.resolver}</dd>
            <dt className="font-semibold py-1">Token</dt>
            <dd className="py-1 break-all">{pool.token}</dd>
            <dt className="font-semibold py-1">Event Start</dt>
            <dd className="py-1">{formatTs(pool.eventStart)}</dd>
            <dt className="font-semibold py-1">Event End</dt>
            <dd className="py-1">{formatTs(pool.eventEnd)}</dd>
            <dt className="font-semibold py-1">Resolve By</dt>
            <dd className="py-1">{formatTs(pool.resolveBy)}</dd>
            <dt className="font-semibold py-1">Resolved At</dt>
            <dd className="py-1">{formatTs(pool.resolvedAt)}</dd>
            {pool.state >= PoolState.SUBMITTED && pool.resolvedAt > 0n && (
              <>
                <dt className="font-semibold py-1">YES Wins</dt>
                <dd className="py-1">{pool.yesWins ? 'Yes' : 'No'}</dd>
              </>
            )}
            <dt className="font-semibold py-1">YES Total</dt>
            <dd className="py-1">{formatUsdc(pool.yesTotal)}</dd>
            <dt className="font-semibold py-1">NO Total</dt>
            <dd className="py-1">{formatUsdc(pool.noTotal)}</dd>
            <dt className="font-semibold py-1">YES Staker Count</dt>
            <dd className="py-1">{yesCount.toString()}</dd>
            <dt className="font-semibold py-1">NO Staker Count</dt>
            <dd className="py-1">{noCount.toString()}</dd>
            <dt className="font-semibold py-1">Per-Wallet Cap</dt>
            <dd className="py-1">{formatUsdc(pool.perWalletCap)}</dd>
            <dt className="font-semibold py-1">Total Pool Cap</dt>
            <dd className="py-1">{formatUsdc(pool.totalPoolCap)}</dd>
            <dt className="font-semibold py-1">Host Commission</dt>
            <dd className="py-1">{pool.hostCommissionBps.toString()} bps</dd>
            <dt className="font-semibold py-1">Losing Staker Count</dt>
            <dd className="py-1">{pool.losingStakerCount.toString()}</dd>
            <dt className="font-semibold py-1">Flag Count</dt>
            <dd className="py-1">{pool.flagCount.toString()}</dd>
            {isConnected && (
              <>
                <dt className="font-semibold py-1">Your YES Stake</dt>
                <dd className="py-1">{formatUsdc(userYesStake)}</dd>
                <dt className="font-semibold py-1">Your NO Stake</dt>
                <dd className="py-1">{formatUsdc(userNoStake)}</dd>
              </>
            )}
          </dl>

          {/* ── Actions ── */}
          <div>
            <h2>Actions</h2>

            {!isConnected && <p>Connect wallet to take actions.</p>}

            {isConnected && (
              <div className="flex flex-col gap-3 max-w-md">

                {/* ── OPEN ── */}
                {pool.state === PoolState.OPEN && (
                  <>
                    <div>
                      <label className="block text-sm font-medium mb-1">Stake amount (USDC)</label>
                      <input
                        value={stakeAmountStr}
                        onChange={(e) => setStakeAmountStr(e.target.value)}
                        placeholder="0.00"
                        disabled={inProgress}
                        className="w-full border rounded px-3 py-2 text-sm"
                      />
                    </div>

                    <button
                      onClick={handleStakeYes}
                      disabled={yesRemaining <= 0n || inProgress}
                      className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                    >
                      {actionState === 'approving' && pendingStake?.isYes === true
                        ? 'Approving…'
                        : actionState === 'staking' && pendingStake?.isYes === true
                        ? 'Staking…'
                        : `Stake YES (${formatUsdc(yesRemaining)} remaining)`}
                    </button>

                    <button
                      onClick={handleStakeNo}
                      disabled={noRemaining <= 0n || inProgress}
                      className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                    >
                      {actionState === 'approving' && pendingStake?.isYes === false
                        ? 'Approving…'
                        : actionState === 'staking' && pendingStake?.isYes === false
                        ? 'Staking…'
                        : `Stake NO (${formatUsdc(noRemaining)} remaining)`}
                    </button>

                    {canClose && (
                      <button
                        onClick={handleClosePool}
                        disabled={inProgress}
                        className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                      >
                        {actionState === 'closing' ? 'Closing…' : 'Close Pool'}
                      </button>
                    )}

                    {canVoidFromOpen && (
                      <button
                        onClick={handleVoidPool}
                        disabled={inProgress}
                        className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                      >
                        {actionState === 'voiding' ? 'Voiding…' : 'Void Pool'}
                      </button>
                    )}
                  </>
                )}

                {/* ── CLOSED ── */}
                {pool.state === PoolState.CLOSED && (
                  <>
                    {canResolve && isResolver && (
                      <>
                        <div className="flex flex-col sm:flex-row gap-3">
                          <label className="flex items-center gap-2">
                            <input
                              type="radio"
                              name="resolveOutcome"
                              checked={resolveYesWins}
                              onChange={() => setResolveYesWins(true)}
                              disabled={inProgress}
                            />
                            YES wins
                          </label>
                          <label className="flex items-center gap-2">
                            <input
                              type="radio"
                              name="resolveOutcome"
                              checked={!resolveYesWins}
                              onChange={() => setResolveYesWins(false)}
                              disabled={inProgress}
                            />
                            NO wins
                          </label>
                        </div>
                        <button
                          onClick={handleResolve}
                          disabled={inProgress}
                          className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                        >
                          {actionState === 'resolving' ? 'Resolving…' : 'Resolve Pool'}
                        </button>
                      </>
                    )}

                    {canVoidFromClosed && (
                      <button
                        onClick={handleVoidPool}
                        disabled={inProgress}
                        className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                      >
                        {actionState === 'voiding' ? 'Voiding…' : 'Void Pool'}
                      </button>
                    )}
                  </>
                )}

                {/* ── SUBMITTED ── */}
                {pool.state === PoolState.SUBMITTED && (
                  <>
                    {withinDisputeWindow && isOnLosingSide && !alreadyFlagged && (
                      <button
                        onClick={handleFlagDispute}
                        disabled={inProgress}
                        className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                      >
                        {actionState === 'flagging' ? 'Flagging…' : 'Flag Dispute'}
                      </button>
                    )}

                    {canFinalize && (
                      <button
                        onClick={handleFinalizePool}
                        disabled={inProgress}
                        className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                      >
                        {actionState === 'finalizing' ? 'Finalizing…' : 'Finalize Pool'}
                      </button>
                    )}
                  </>
                )}

                {/* ── FINALIZED ── */}
                {pool.state === PoolState.FINALIZED && (
                  <>
                    {isOnWinningSide && !hasClaimed && (
                      <button
                        onClick={handleClaim}
                        disabled={inProgress}
                        className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                      >
                        {actionState === 'claiming' ? 'Claiming…' : 'Claim Winnings'}
                      </button>
                    )}
                  </>
                )}

                {/* ── VOIDED ── */}
                {pool.state === PoolState.VOIDED && (
                  <>
                    {isStaker && !hasClaimed && (
                      <button
                        onClick={handleClaim}
                        disabled={inProgress}
                        className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                      >
                        {actionState === 'claiming' ? 'Claiming…' : 'Claim Refund'}
                      </button>
                    )}
                  </>
                )}

                {/* ── DISPUTED ── */}
                {pool.state === PoolState.DISPUTED && (
                  <>
                    {isAdmin && (
                      <>
                        <div className="flex flex-col sm:flex-row gap-3">
                          <label className="flex items-center gap-2">
                            <input
                              type="radio"
                              name="adminOutcome"
                              checked={resolveYesWins}
                              onChange={() => setResolveYesWins(true)}
                              disabled={inProgress}
                            />
                            YES wins
                          </label>
                          <label className="flex items-center gap-2">
                            <input
                              type="radio"
                              name="adminOutcome"
                              checked={!resolveYesWins}
                              onChange={() => setResolveYesWins(false)}
                              disabled={inProgress}
                            />
                            NO wins
                          </label>
                        </div>
                        <button
                          onClick={handleAdminResolve}
                          disabled={inProgress}
                          className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                        >
                          {actionState === 'adminResolving' ? 'Resolving…' : 'Admin Resolve Pool'}
                        </button>
                      </>
                    )}
                  </>
                )}

                {/* ── Transaction feedback ── */}
                {inProgress && actionState !== 'approving' && actionState !== 'staking' && (
                  <p>Pending…</p>
                )}
                {(actionState === 'approving' || actionState === 'staking') && (
                  <p>
                    {actionState === 'approving' ? 'Waiting for approval…' : 'Waiting for stake…'}
                  </p>
                )}
                {actionState === 'done' && mainTxHash && (
                  <p>
                    Success! Tx:{' '}
                    <span className="font-mono">
                      {truncateAddr(mainTxHash)}
                    </span>
                  </p>
                )}
                {actionState === 'error' && (
                  <div>
                    <p className="text-red-500">
                      Error:{' '}
                      {parseRevertReason(approveError ?? mainError)}
                    </p>
                    <button
                      onClick={handleReset}
                      className="w-full py-2 mt-2 border rounded"
                    >
                      Reset
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  )
}
