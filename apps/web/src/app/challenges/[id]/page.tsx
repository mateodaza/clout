'use client'
import { use, useState, useEffect, useRef } from 'react'
import { useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi'
import { zeroAddress } from 'viem'
import { ChallengeState, Outcome } from '@clout/types'
import { cloutEscrowAbi, mockStablecoinAbi, ESCROW_ADDRESS } from '@/lib/contracts'
import Link from 'next/link'
import { Spinner } from '@/components/Spinner'
import { ChallengeStateBadge } from '@/components/StateBadge'
import { parseRevertReason } from '@/lib/errors'
import { useToast } from '@/contexts/ToastContext'

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

function formatTs(ts: bigint): string {
  return ts === 0n ? '—' : new Date(Number(ts) * 1000).toLocaleString()
}

function outcomeLabel(o: Outcome): string {
  return ['None', 'Creator Win', 'Opponent Win', 'Draw', 'Invalid'][o] ?? 'Unknown'
}

// --- Component ---

export default function ChallengeDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const isValidId = /^\d+$/.test(id)
  const challengeId = isValidId ? BigInt(id) : 0n

  const [actionState, setActionState] = useState<ActionState>('idle')
  const [selectedOutcome, setSelectedOutcome] = useState<number>(Outcome.CREATOR_WIN)
  const { addToast, updateToast } = useToast()
  const approveToastId = useRef<string | null>(null)
  const mainToastId = useRef<string | null>(null)

  const { address: connectedAddress, isConnected } = useAccount()

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

  function handleReset() {
    setActionState('idle')
    approveToastId.current = null
    mainToastId.current = null
  }

  // --- Render ---

  return (
    <div style={{ padding: '1rem' }}>
      <div style={{ marginBottom: '1rem' }}>
        <Link href="/challenges">← Back to Challenges</Link>
      </div>
      <h1>Challenge #{id}</h1>

      {isLoading && <Spinner />}

      {!isLoading && !challengeExists && <p>Challenge not found.</p>}

      {challengeExists && challenge && (
        <>
          {/* Fields section */}
          <table style={{ borderCollapse: 'collapse', marginBottom: '1.5rem' }}>
            <tbody>
              <tr>
                <td style={labelStyle}>Creator</td>
                <td style={valueStyle}>{challenge.creator}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Opponent</td>
                <td style={valueStyle}>{challenge.opponent}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Stake</td>
                <td style={valueStyle}>{formatStake(challenge.stakeAmount, challenge.token)}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Token</td>
                <td style={valueStyle}>{challenge.token}</td>
              </tr>
              <tr>
                <td style={labelStyle}>State</td>
                <td style={valueStyle}>
                  <ChallengeStateBadge state={challenge.state} />
                </td>
              </tr>
              <tr>
                <td style={labelStyle}>Game ID</td>
                <td style={valueStyle}>{challenge.gameId}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Match ID</td>
                <td style={valueStyle}>{challenge.matchId}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Designated Resolver</td>
                <td style={valueStyle}>
                  {challenge.designatedResolver === zeroAddress
                    ? 'None (admin only)'
                    : challenge.designatedResolver}
                </td>
              </tr>
              <tr>
                <td style={labelStyle}>Submitted Result</td>
                <td style={valueStyle}>{outcomeLabel(challenge.submittedResult)}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Submitted By</td>
                <td style={valueStyle}>
                  {challenge.submittedBy === zeroAddress
                    ? '—'
                    : truncateAddr(challenge.submittedBy)}
                </td>
              </tr>
              <tr>
                <td style={labelStyle}>Claimed</td>
                <td style={valueStyle}>{challenge.claimed ? 'Yes' : 'No'}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Appealed</td>
                <td style={valueStyle}>{challenge.appealed ? 'Yes' : 'No'}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Created At</td>
                <td style={valueStyle}>{formatTs(challenge.createdAt)}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Accepted At</td>
                <td style={valueStyle}>{formatTs(challenge.acceptedAt)}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Submitted At</td>
                <td style={valueStyle}>{formatTs(challenge.submittedAt)}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Disputed At</td>
                <td style={valueStyle}>{formatTs(challenge.disputedAt)}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Resolved At</td>
                <td style={valueStyle}>{formatTs(challenge.resolvedAt)}</td>
              </tr>
              <tr>
                <td style={labelStyle}>Appealed At</td>
                <td style={valueStyle}>{formatTs(challenge.appealedAt)}</td>
              </tr>
            </tbody>
          </table>

          {/* Actions section */}
          {isConnected ? (
            <div>
              {/* CREATED: Accept */}
              {challenge.state === ChallengeState.CREATED && isOpponent && (
                <button onClick={handleAccept} disabled={inProgress}>
                  {actionState === 'approving'
                    ? 'Approving token...'
                    : actionState === 'accepting'
                    ? 'Accepting...'
                    : 'Accept Challenge'}
                </button>
              )}

              {/* ACCEPTED: Submit Result */}
              {challenge.state === ChallengeState.ACCEPTED && isParticipant && (
                <div>
                  <OutcomeSelector
                    value={selectedOutcome}
                    onChange={setSelectedOutcome}
                    includeInvalid={false}
                  />
                  <button onClick={handleSubmitResult} disabled={inProgress}>
                    {actionState === 'submitting' ? 'Submitting...' : 'Submit Result'}
                  </button>
                </div>
              )}

              {/* SUBMITTED: Confirm or Dispute */}
              {challenge.state === ChallengeState.SUBMITTED && isNonSubmitter && (
                <div style={{ display: 'flex', gap: '0.5rem' }}>
                  <button onClick={handleConfirm} disabled={inProgress}>
                    {actionState === 'confirming' ? 'Confirming...' : 'Confirm Result'}
                  </button>
                  <button onClick={handleDispute} disabled={inProgress}>
                    {actionState === 'disputing' ? 'Disputing...' : 'Dispute Result'}
                  </button>
                </div>
              )}

              {/* DISPUTED: Resolve */}
              {challenge.state === ChallengeState.DISPUTED && (isResolver || adminCanResolve) && (
                <div>
                  <OutcomeSelector
                    value={selectedOutcome}
                    onChange={setSelectedOutcome}
                    includeInvalid={true}
                  />
                  <button onClick={handleResolve} disabled={inProgress}>
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
                  <button onClick={handleAppeal} disabled={inProgress}>
                    {actionState === 'appealing' ? 'Appealing...' : 'Appeal Resolution'}
                  </button>
                )}

              {/* FINALIZED or VOIDED: Claim */}
              {(challenge.state === ChallengeState.FINALIZED ||
                challenge.state === ChallengeState.VOIDED) &&
                isParticipant &&
                !challenge.claimed && (
                  <button onClick={handleClaim} disabled={inProgress}>
                    {actionState === 'claiming' ? 'Claiming...' : 'Claim Winnings'}
                  </button>
                )}

              {/* Transaction feedback */}
              {approveTxHash && actionState === 'approving' && (
                <p style={{ fontSize: '0.85rem', marginTop: '0.5rem' }}>
                  Approve tx: {approveTxHash}
                </p>
              )}
              {mainTxHash && (actionState === 'done' || inProgress) && (
                <p style={{ fontSize: '0.85rem', marginTop: '0.5rem' }}>
                  Tx: {mainTxHash}
                </p>
              )}
              {actionState === 'done' && (
                <p style={{ color: 'green', marginTop: '0.5rem' }}>
                  Transaction confirmed. Challenge updated.
                </p>
              )}
              {actionState === 'error' && (
                <div style={{ marginTop: '0.5rem' }}>
                  <p style={{ color: 'red' }}>
                    Error: {parseRevertReason(approveError ?? mainError)}
                  </p>
                  <button onClick={handleReset}>Reset</button>
                </div>
              )}
            </div>
          ) : (
            <p>Connect wallet to take actions.</p>
          )}
        </>
      )}
    </div>
  )
}

// --- Shared styles ---

const labelStyle: React.CSSProperties = {
  padding: '0.3rem 0.75rem 0.3rem 0',
  fontWeight: 'bold',
  verticalAlign: 'top',
  whiteSpace: 'nowrap',
}

const valueStyle: React.CSSProperties = {
  padding: '0.3rem 0',
  wordBreak: 'break-all',
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
    <div style={{ marginBottom: '0.5rem' }}>
      <label style={{ marginRight: '0.5rem' }}>Outcome:</label>
      <select value={value} onChange={(e) => onChange(Number(e.target.value))}>
        <option value={Outcome.CREATOR_WIN}>Creator Win</option>
        <option value={Outcome.OPPONENT_WIN}>Opponent Win</option>
        <option value={Outcome.DRAW}>Draw</option>
        {includeInvalid && <option value={Outcome.INVALID}>Invalid</option>}
      </select>
    </div>
  )
}
