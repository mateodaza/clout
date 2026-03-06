import React from 'react'
import { ChallengeState, Outcome } from '@clout/types'
import { formatTimestamp, basescanUrl } from '@/lib/utils'

type TimestampedEntry = { kind: 'ts'; ts: bigint; label: React.ReactNode }
type StaticEntry = { kind: 'static'; label: React.ReactNode }
type TimelineEntry = TimestampedEntry | StaticEntry

type ChallengeTimelineProps = {
  state: ChallengeState
  creator: `0x${string}`
  opponent: `0x${string}`
  submittedBy: `0x${string}`
  submittedResult: Outcome
  createdAt: bigint
  acceptedAt: bigint
  submittedAt: bigint
  disputedAt: bigint
  resolvedAt: bigint
  appealedAt: bigint
}

function truncateAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

function outcomeLabel(o: Outcome): string {
  const labels: Record<number, string> = {
    [Outcome.NONE]: 'None',
    [Outcome.CREATOR_WIN]: 'Creator wins',
    [Outcome.OPPONENT_WIN]: 'Opponent wins',
    [Outcome.DRAW]: 'Draw',
    [Outcome.INVALID]: 'Invalid',
  }
  return labels[o] ?? 'Unknown'
}

export function ChallengeTimeline({
  state,
  creator,
  opponent,
  submittedBy,
  submittedResult,
  createdAt,
  acceptedAt,
  submittedAt,
  disputedAt,
  resolvedAt,
  appealedAt,
}: ChallengeTimelineProps) {
  const candidates: TimestampedEntry[] = [
    { kind: 'ts', ts: createdAt, label: <>Created by <a href={basescanUrl('address', creator)} target="_blank" rel="noopener" aria-label={`View creator address on Basescan: ${creator}`}>{truncateAddr(creator)}</a></> },
    { kind: 'ts', ts: acceptedAt, label: <>Accepted by <a href={basescanUrl('address', opponent)} target="_blank" rel="noopener" aria-label={`View opponent address on Basescan: ${opponent}`}>{truncateAddr(opponent)}</a></> },
    { kind: 'ts', ts: submittedAt, label: <>Result submitted by <a href={basescanUrl('address', submittedBy)} target="_blank" rel="noopener" aria-label={`View submitter address on Basescan: ${submittedBy}`}>{truncateAddr(submittedBy)}</a></> },
    { kind: 'ts', ts: disputedAt, label: 'Result disputed' },
    { kind: 'ts', ts: resolvedAt, label: 'Dispute resolved' },
    { kind: 'ts', ts: appealedAt, label: 'Resolution appealed' },
  ]

  const timestamped = candidates
    .filter((e) => e.ts > 0n)
    .sort((a, b) => (a.ts < b.ts ? -1 : a.ts > b.ts ? 1 : 0))

  const terminal: StaticEntry[] = []
  if (state === ChallengeState.FINALIZED) {
    terminal.push({ kind: 'static', label: `Finalized: ${outcomeLabel(submittedResult)}` })
  } else if (state === ChallengeState.VOIDED) {
    terminal.push({ kind: 'static', label: 'Voided' })
  }

  const entries: TimelineEntry[] = [...timestamped, ...terminal]

  return (
    <section className="mt-8">
      <h2 className="text-lg font-semibold mb-4">Timeline</h2>
      <ol className="relative border-l border-gray-200 dark:border-gray-700 ml-3">
        {entries.map((entry, i) => (
          <li key={i} className="mb-6 ml-4">
            <div className="absolute w-3 h-3 rounded-full -left-1.5 mt-1 bg-gray-300 dark:bg-gray-600 border border-white dark:border-gray-900" />
            <time className="block mb-0.5 text-xs text-gray-400 dark:text-gray-500">
              {entry.kind === 'ts' ? formatTimestamp(entry.ts) : '—'}
            </time>
            <p className="text-sm text-gray-700 dark:text-gray-300">{entry.label}</p>
          </li>
        ))}
      </ol>
    </section>
  )
}
