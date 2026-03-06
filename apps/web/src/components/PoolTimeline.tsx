import { PoolState } from '@clout/types'
import { formatTimestamp } from '@/lib/utils'

type TimestampedEntry = { kind: 'ts'; ts: bigint; label: string }
type StaticEntry = { kind: 'static'; label: string }
type TimelineEntry = TimestampedEntry | StaticEntry

type PoolTimelineProps = {
  host: `0x${string}`
  eventStart: bigint
  resolvedAt: bigint
  yesWins: boolean
  state: number
}

function truncateAddr(addr: string): string {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}

export function PoolTimeline({ host, eventStart, resolvedAt, yesWins, state }: PoolTimelineProps) {
  const timestampedCandidates: Array<{ ts: bigint; condition: boolean; label: string }> = [
    { ts: eventStart, condition: state >= PoolState.CLOSED, label: 'Event started — pool closed' },
    { ts: resolvedAt, condition: resolvedAt > 0n, label: 'Resolver submitted result' },
  ]

  const timestamped: TimestampedEntry[] = timestampedCandidates
    .filter((e) => e.ts > 0n && e.condition)
    .map((e) => ({ kind: 'ts' as const, ts: e.ts, label: e.label }))
    .sort((a, b) => (a.ts < b.ts ? -1 : a.ts > b.ts ? 1 : 0))

  const terminal: StaticEntry[] = []
  if (state === PoolState.FINALIZED) {
    terminal.push({ kind: 'static', label: `Finalized: ${yesWins ? 'YES' : 'NO'} wins` })
  } else if (state === PoolState.VOIDED) {
    terminal.push({ kind: 'static', label: 'Voided' })
  }

  const entries: TimelineEntry[] = [
    { kind: 'static', label: `Created by ${truncateAddr(host)}` },
    ...timestamped,
    ...terminal,
  ]

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
