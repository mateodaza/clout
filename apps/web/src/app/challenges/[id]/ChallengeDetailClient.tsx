'use client'

import { use, useState, useEffect, useRef } from 'react'
import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi'
import { formatUnits, zeroAddress } from 'viem'
import { ChallengeState, Outcome } from '@clout/types'
import { cloutEscrowAbi, mockStablecoinAbi, ESCROW_ADDRESS } from '@/lib/contracts'
import Link from 'next/link'
import { Skeleton } from '@/components/Skeleton'
import { ChallengeStateBadge } from '@/components/StateBadge'
import { ConnectWallet } from '@/components/ConnectWallet'
import { parseRevertReason } from '@/lib/errors'
import { useToast } from '@/contexts/ToastContext'
import { formatTimestamp, basescanUrl } from '@/lib/utils'
import { Countdown } from '@/components/Countdown'
import { ChallengeTimeline } from '@/components/ChallengeTimeline'
import ShareButtons from '@/components/ShareButtons'
import { ConfirmDialog } from '@/components/ConfirmDialog'
import { useWrongChain } from '@/lib/useWrongChain'

// --- Local Types ---

type ParsedChallenge = {
  creator: `0x${string}`
  opponent: `0x${string}`
  designatedResolver: `0x${string}`
  token: `0x${string}`
  stakeAmount: bigint
  state: ChallengeState
  gameId: `0x${string}`
  matchId: `0x${string}`
  submittedResult: Outcome
  submittedBy: `0x${string}`
  createdAt: bigint
  acceptedAt: bigint
  submittedAt: bigint
  disputedAt: bigint
  resolvedAt: bigint
  claimed: boolean
  appealed: boolean
  appealedAt: bigint
}

type ActionState =
  | 'idle'
  | 'approving'
  | 'accepting'
  | 'submitting'
  | 'confirming'
  | 'disputing'
  | 'resolving'
  | 'claiming'
  | 'appealing'
  | 'done'
  | 'error'

// --- Helpers ---

function parseTuple(raw: readonly unknown[]): ParsedChallenge {
  return {
    creator: raw[0] as `0x${string}`,
    opponent: raw[1] as `0x${string}`,
    designatedResolver: raw[2] as `0x${string}`,
    token: raw[3] as `0x${string}`,
    stakeAmount: raw[4] as bigint,
    state: raw[5] as ChallengeState,
    gameId: raw[6] as `0x${string}`,
    matchId: raw[7] as `0x${string}`,
    submittedResult: raw[8] as Outcome,
    submittedBy: raw[9] as `0x${string}`,
    createdAt: raw[10] as bigint,
    acceptedAt: raw[11] as bigint,
    submittedAt: raw[12] as bigint,
    disputedAt: raw[13] as bigint,
    resolvedAt: raw[14] as bigint,
    claimed: raw[15] as boolean,
    appealed: raw[16] as boolean,
    appealedAt: raw[17] as bigint,
  }
}

function truncateAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

function formatStake(amount: bigint, token: string): string {
  return (Number(amount) / 1_000_000).toFixed(2) + ' (' + truncateAddr(token) + ')'
}

const VOID_TIMEOUT = 172800n    // 48h
const SUBMIT_TIMEOUT = 86400n   // 24h

function outcomeLabel(o: Outcome): string {
  return ['None', 'Creator Win', 'Opponent Win', 'Draw', 'Invalid'][o] ?? 'Unknown'
}

// --- Component ---

export function ChallengeDetailClient({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const isValidId = /^\d+$/.test(id)
  const challengeId = isValidId ? BigInt(id) : 0n

  const [actionState, setActionState] = useState<ActionState>('idle')
  const [selectedOutcome, setSelectedOutcome] = useState<number>(Outcome.CREATOR_WIN)
  const [pendingConfirm, setPendingConfirm] = useState<{
    title: string
    message: string
    onConfirm: () => void
  } | null>(null)
  const { addToast, updateToast } = useToast()
  const approveToastId = useRef<string | null>(null)
  const mainToastId = useRef<string | null>(null)

  const { address: connectedAddress, isConnected } = useAccount()
  const isWrongChain = useWrongChain()

  const {
    data: rawChallenge,
    isLoading,
    refetch,
  } = useReadContract({
    address: ESCROW_ADDRESS,
    abi: cloutEscrowAbi,
    functionName: 'challenges',
    args: [challengeId],
    query: { enabled: isValidId },
  })

  const { data: ownerAddress } = useReadContract({
    address: ESCROW_ADDRESS,
    abi: cloutEscrowAbi,
    functionName: 'owner',
  })

  const {
    writeContract: approveWrite,
    data: approveTxHash,
    error: approveError,
  } = useWriteContract()

  const { isSuccess: approveConfirmed } = useWaitForTransactionReceipt({
    hash: approveTxHash,
  })

  const {
    writeContract: mainWrite,
    data: mainTxHash,
    error: mainError,
  } = useWriteContract()

  const { isSuccess: mainConfirmed } = useWaitForTransactionReceipt({
    hash: mainTxHash,
  })

  // Effect 1: chain approve → accept
  useEffect(() => {
    if (approveConfirmed && actionState === 'approving') {
      setActionState('accepting')
      mainWrite({
        address: ESCROW_ADDRESS,
        abi: cloutEscrowAbi,
        functionName: 'acceptChallenge',
        args: [challengeId],
      })
    }
  }, [approveConfirmed, actionState])

  // Effect 2: refetch on success
  useEffect(() => {
    if (mainConfirmed) {
      setActionState('done')
      refetch()
    }
  }, [mainConfirmed])

  // Effect 3: surface errors
  useEffect(() => {
    if ((approveError || mainError) && actionState !== 'idle') {
      setActionState('error')
    }
  }, [approveError, mainError])

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

  // Toast effects: main tx
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

  // Parse challenge
  const challenge = rawChallenge ? parseTuple(rawChallenge as readonly unknown[]) : null
  const challengeExists = isValidId && challenge !== null && challenge.creator !== zeroAddress

  // Derived roles
  const addr = connectedAddress?.toLowerCase()
  const isCreator = !!addr && addr === challenge?.creator.toLowerCase()
  const isOpponent = !!addr && addr === challenge?.opponent.toLowerCase()
  const isParticipant = isCreator || isOpponent
  const isNonSubmitter =
    isParticipant && !!challenge && addr !== challenge.submittedBy.toLowerCase()
  const isResolver =
    !!addr &&
    !!challenge &&
    challenge.designatedResolver !== zeroAddress &&
    addr === challenge.designatedResolver.toLowerCase()
  const isAdmin =
    !!addr && addr === (ownerAddress as string | undefined)?.toLowerCase()
  const inProgress =
    actionState !== 'idle' && actionState !== 'done' && actionState !== 'error'

  const nowSeconds = BigInt(Math.floor(Date.now() / 1000))
  // Admin can call resolveDisputeAsAdmin immediately only when no resolver is set.
  // When a resolver is designated, admin must wait 48h after disputedAt.
  const adminCanResolve =
    isAdmin &&
    !isResolver &&
    !!challenge &&
    (challenge.designatedResolver === zeroAddress ||
      nowSeconds >= challenge.disputedAt + 172800n)
  // Appeal window: 24h after resolvedAt
  const appealWindowOpen =
    !!challenge && nowSeconds < challenge.resolvedAt + 86400n

  // --- Action Handlers ---

  function handleAccept() {
    if (!challenge) return
    setActionState('approving')
    approveWrite({
      address: challenge.token,
      abi: mockStablecoinAbi,
      functionName: 'approve',
      args: [ESCROW_ADDRESS, challenge.stakeAmount],
    })
  }

  function handleSubmitResult() {
    setActionState('submitting')
    mainWrite({
      address: ESCROW_ADDRESS,
      abi: cloutEscrowAbi,
      functionName: 'submitResult',
      args: [challengeId, selectedOutcome],
    })
  }

  function handleConfirm() {
    setActionState('confirming')
    mainWrite({
      address: ESCROW_ADDRESS,
      abi: cloutEscrowAbi,
      functionName: 'confirmResult',
      args: [challengeId],
    })
  }

  function handleDispute() {
    setActionState('disputing')
    mainWrite({
      address: ESCROW_ADDRESS,
      abi: cloutEscrowAbi,
      functionName: 'disputeResult',
      args: [challengeId],
    })
  }

  function handleResolve() {
    setActionState('resolving')
    if (isResolver) {
      mainWrite({
        address: ESCROW_ADDRESS,
        abi: cloutEscrowAbi,
        functionName: 'resolveDispute',
        args: [challengeId, selectedOutcome],
      })
    } else {
      mainWrite({
        address: ESCROW_ADDRESS,
        abi: cloutEscrowAbi,
        functionName: 'resolveDisputeAsAdmin',
        args: [challengeId, selectedOutcome],
      })
    }
  }

  function handleClaim() {
    setActionState('claiming')
    mainWrite({
      address: ESCROW_ADDRESS,
      abi: cloutEscrowAbi,
      functionName: 'claimWinnings',
      args: [challengeId],
    })
  }

  function handleAppeal() {
    setActionState('appealing')
    mainWrite({
      address: ESCROW_ADDRESS,
      abi: cloutEscrowAbi,
      functionName: 'appealResolution',
      args: [challengeId],
    })
  }

  function requestConfirm(title: string, message: string, onConfirm: () => void) {
    setPendingConfirm({ title, message, onConfirm })
  }
  function dismissConfirm() {
    setPendingConfirm(null)
  }

  function handleReset() {
    setActionState('idle')
    approveToastId.current = null
    mainToastId.current = null
  }

  // --- Render ---

  return (
    <div>
      <div className="mb-4">
        <Link href="/challenges" aria-label="Back to challenges list">← Back to Challenges</Link>
      </div>
      <h1>Challenge #{id}</h1>
      <ShareButtons tweetText="I just staked on a challenge on Clout!" />

      {isLoading && (
        <div className="flex flex-col gap-4 mt-4">
          <Skeleton width="8rem" height="1.75rem" />
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

      {!isLoading && !challengeExists && <p>Challenge not found.</p>}

      {challengeExists && challenge && (
        <>
          {/* Fields section */}
          <dl className="grid grid-cols-1 sm:grid-cols-[auto_1fr] gap-x-6 gap-y-1 mb-6 mt-4">
            <dt className="font-semibold py-1">Creator</dt>
            <dd className="py-1 break-all"><a href={basescanUrl('address', challenge.creator)} target="_blank" rel="noopener" aria-label={`View creator address on Basescan: ${challenge.creator}`}>{truncateAddr(challenge.creator)}</a></dd>
            <dt className="font-semibold py-1">Opponent</dt>
            <dd className="py-1 break-all"><a href={basescanUrl('address', challenge.opponent)} target="_blank" rel="noopener" aria-label={`View opponent address on Basescan: ${challenge.opponent}`}>{truncateAddr(challenge.opponent)}</a></dd>
            <dt className="font-semibold py-1">Stake</dt>
            <dd className="py-1">{formatStake(challenge.stakeAmount, challenge.token)}</dd>
            <dt className="font-semibold py-1">Token</dt>
            <dd className="py-1 break-all"><a href={basescanUrl('address', challenge.token)} target="_blank" rel="noopener" aria-label={`View token contract on Basescan: ${challenge.token}`}>{truncateAddr(challenge.token)}</a></dd>
            <dt className="font-semibold py-1">State</dt>
            <dd className="py-1"><ChallengeStateBadge state={challenge.state} /></dd>
            <dt className="font-semibold py-1">Game ID</dt>
            <dd className="py-1 break-all">{challenge.gameId}</dd>
            <dt className="font-semibold py-1">Match ID</dt>
            <dd className="py-1 break-all">{challenge.matchId}</dd>
            <dt className="font-semibold py-1">Designated Resolver</dt>
            <dd className="py-1 break-all">
              {challenge.designatedResolver === zeroAddress
                ? 'None (admin only)'
                : <a href={basescanUrl('address', challenge.designatedResolver)} target="_blank" rel="noopener" aria-label={`View designated resolver on Basescan: ${challenge.designatedResolver}`}>{truncateAddr(challenge.designatedResolver)}</a>}
            </dd>
            <dt className="font-semibold py-1">Submitted Result</dt>
            <dd className="py-1">{outcomeLabel(challenge.submittedResult)}</dd>
            <dt className="font-semibold py-1">Submitted By</dt>
            <dd className="py-1">
              {challenge.submittedBy === zeroAddress
                ? '—'
                : <a href={basescanUrl('address', challenge.submittedBy)} target="_blank" rel="noopener" aria-label={`View submitter address on Basescan: ${challenge.submittedBy}`}>{truncateAddr(challenge.submittedBy)}</a>}
            </dd>
            <dt className="font-semibold py-1">Claimed</dt>
            <dd className="py-1">{challenge.claimed ? 'Yes' : 'No'}</dd>
            <dt className="font-semibold py-1">Appealed</dt>
            <dd className="py-1">{challenge.appealed ? 'Yes' : 'No'}</dd>
            <dt className="font-semibold py-1">Created At</dt>
            <dd className="py-1">
              {formatTimestamp(challenge.createdAt)}
              {challenge.state === ChallengeState.CREATED && (
                <> · <Countdown expiresAt={challenge.createdAt + VOID_TIMEOUT} /></>
              )}
            </dd>
            <dt className="font-semibold py-1">Accepted At</dt>
            <dd className="py-1">
              {formatTimestamp(challenge.acceptedAt)}
              {challenge.state === ChallengeState.ACCEPTED && (
                <> · <Countdown expiresAt={challenge.acceptedAt + VOID_TIMEOUT} /></>
              )}
            </dd>
            <dt className="font-semibold py-1">Submitted At</dt>
            <dd className="py-1">
              {formatTimestamp(challenge.submittedAt)}
              {challenge.state === ChallengeState.SUBMITTED && (
                <> · <Countdown expiresAt={challenge.submittedAt + SUBMIT_TIMEOUT} /></>
              )}
            </dd>
            <dt className="font-semibold py-1">Disputed At</dt>
            <dd className="py-1">
              {formatTimestamp(challenge.disputedAt)}
              {challenge.state === ChallengeState.DISPUTED && (
                <> · <Countdown expiresAt={challenge.disputedAt + VOID_TIMEOUT} /></>
              )}
            </dd>
            <dt className="font-semibold py-1">Resolved At</dt>
            <dd className="py-1">
              {formatTimestamp(challenge.resolvedAt)}
              {challenge.state === ChallengeState.RESOLVED && (
                <> · <Countdown expiresAt={challenge.resolvedAt + SUBMIT_TIMEOUT} /></>
              )}
            </dd>
            <dt className="font-semibold py-1">Appealed At</dt>
            <dd className="py-1">{formatTimestamp(challenge.appealedAt)}</dd>
          </dl>

          <ChallengeTimeline
            state={challenge.state}
            creator={challenge.creator}
            opponent={challenge.opponent}
            submittedBy={challenge.submittedBy}
            submittedResult={challenge.submittedResult}
            createdAt={challenge.createdAt}
            acceptedAt={challenge.acceptedAt}
            submittedAt={challenge.submittedAt}
            disputedAt={challenge.disputedAt}
            resolvedAt={challenge.resolvedAt}
            appealedAt={challenge.appealedAt}
          />

          {/* Actions section */}
          {isConnected ? (
            <div className="flex flex-col gap-3 max-w-md">
              {/* CREATED: Accept */}
              {challenge.state === ChallengeState.CREATED && isOpponent && (
                <button
                  onClick={() => requestConfirm('Accept Challenge', `You are about to stake ${formatUnits(challenge.stakeAmount, 6)} USDC. Confirm?`, handleAccept)}
                  disabled={inProgress || isWrongChain}
                  aria-label="Accept challenge — approve token and stake"
                  className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                >
                  {actionState === 'approving'
                    ? 'Approving token...'
                    : actionState === 'accepting'
                    ? 'Accepting...'
                    : 'Accept Challenge'}
                </button>
              )}

              {/* ACCEPTED: Submit Result */}
              {challenge.state === ChallengeState.ACCEPTED && isParticipant && (
                <div className="flex flex-col gap-2">
                  <OutcomeSelector
                    value={selectedOutcome}
                    onChange={setSelectedOutcome}
                    includeInvalid={false}
                  />
                  <button
                    onClick={handleSubmitResult}
                    disabled={inProgress || isWrongChain}
                    aria-label="Submit your result for this challenge"
                    className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                  >
                    {actionState === 'submitting' ? 'Submitting...' : 'Submit Result'}
                  </button>
                </div>
              )}

              {/* SUBMITTED: Confirm or Dispute */}
              {challenge.state === ChallengeState.SUBMITTED && isNonSubmitter && (
                <div className="flex flex-col sm:flex-row gap-2">
                  <button
                    onClick={handleConfirm}
                    disabled={inProgress || isWrongChain}
                    aria-label="Confirm the submitted result"
                    className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                  >
                    {actionState === 'confirming' ? 'Confirming...' : 'Confirm Result'}
                  </button>
                  <button
                    onClick={() => requestConfirm('Dispute Result', 'Filing a dispute escalates to the resolver/admin. Continue?', handleDispute)}
                    disabled={inProgress || isWrongChain}
                    aria-label="Dispute the submitted result — escalate to resolver"
                    className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                  >
                    {actionState === 'disputing' ? 'Disputing...' : 'Dispute Result'}
                  </button>
                </div>
              )}

              {/* DISPUTED: Resolve */}
              {challenge.state === ChallengeState.DISPUTED && (isResolver || adminCanResolve) && (
                <div className="flex flex-col gap-2">
                  <OutcomeSelector
                    value={selectedOutcome}
                    onChange={setSelectedOutcome}
                    includeInvalid={true}
                  />
                  <button
                    onClick={handleResolve}
                    disabled={inProgress || isWrongChain}
                    aria-label="Resolve the dispute and set the final outcome"
                    className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                  >
                    {actionState === 'resolving' ? 'Resolving...' : 'Resolve Dispute'}
                  </button>
                </div>
              )}

              {/* RESOLVED: Appeal */}
              {challenge.state === ChallengeState.RESOLVED &&
                isParticipant &&
                !challenge.appealed &&
                challenge.designatedResolver !== zeroAddress &&
                appealWindowOpen && (
                  <button
                    onClick={handleAppeal}
                    disabled={inProgress || isWrongChain}
                    aria-label="Appeal the resolution — escalate to admin"
                    className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                  >
                    {actionState === 'appealing' ? 'Appealing...' : 'Appeal Resolution'}
                  </button>
                )}

              {/* FINALIZED or VOIDED: Claim */}
              {(challenge.state === ChallengeState.FINALIZED ||
                challenge.state === ChallengeState.VOIDED) &&
                isParticipant &&
                !challenge.claimed && (
                  <button
                    onClick={() => requestConfirm('Claim Winnings', 'Claim your winnings from this challenge?', handleClaim)}
                    disabled={inProgress || isWrongChain}
                    aria-label="Claim your winnings from this challenge"
                    className="w-full py-2.5 px-4 border rounded disabled:opacity-50"
                  >
                    {actionState === 'claiming' ? 'Claiming...' : 'Claim Winnings'}
                  </button>
                )}

              {/* Transaction feedback */}
              {approveTxHash && actionState === 'approving' && (
                <p className="text-sm mt-1">Approve tx: <a href={basescanUrl('tx', approveTxHash)} target="_blank" rel="noopener" aria-label="View token approval transaction on Basescan">{truncateAddr(approveTxHash)}</a></p>
              )}
              {mainTxHash && (actionState === 'done' || inProgress) && (
                <p className="text-sm mt-1">Tx: <a href={basescanUrl('tx', mainTxHash)} target="_blank" rel="noopener" aria-label="View transaction on Basescan">{truncateAddr(mainTxHash)}</a></p>
              )}
              {actionState === 'done' && (
                <p className="text-green-600 mt-1">Transaction confirmed. Challenge updated.</p>
              )}
              {actionState === 'error' && (
                <div className="mt-1">
                  <p className="text-red-500">
                    Error: {parseRevertReason(approveError ?? mainError)}
                  </p>
                  <button
                    onClick={handleReset}
                    aria-label="Reset — try again after error"
                    className="w-full py-2 mt-2 border rounded"
                  >
                    Reset
                  </button>
                </div>
              )}
            </div>
          ) : (
            <div className="mb-6 p-4 border rounded">
              <p className="mb-3">Connect your wallet to take actions.</p>
              <ConnectWallet />
            </div>
          )}
        </>
      )}
      {pendingConfirm && (
        <ConfirmDialog
          title={pendingConfirm.title}
          message={pendingConfirm.message}
          onConfirm={() => { const fn = pendingConfirm.onConfirm; dismissConfirm(); fn() }}
          onCancel={dismissConfirm}
        />
      )}
    </div>
  )
}

// --- Outcome Selector Sub-component ---

function OutcomeSelector({
  value,
  onChange,
  includeInvalid,
}: {
  value: number
  onChange: (v: number) => void
  includeInvalid: boolean
}) {
  return (
    <div>
      <label className="block text-sm font-medium mb-1">Outcome</label>
      <select
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="w-full sm:w-auto border rounded px-2 py-1"
      >
        <option value={Outcome.CREATOR_WIN}>Creator Win</option>
        <option value={Outcome.OPPONENT_WIN}>Opponent Win</option>
        <option value={Outcome.DRAW}>Draw</option>
        {includeInvalid && <option value={Outcome.INVALID}>Invalid</option>}
      </select>
    </div>
  )
}
