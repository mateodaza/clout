import { ChallengeState, PoolState } from '@clout/types'

const BADGE_STYLE_BASE: React.CSSProperties = {
  display: 'inline-block',
  borderRadius: '9999px',
  padding: '0.1rem 0.55rem',
  fontSize: '0.75rem',
  fontWeight: 600,
}

const COLOR: Record<string, React.CSSProperties> = {
  green:  { background: '#dcfce7', color: '#166534' },
  yellow: { background: '#fef9c3', color: '#854d0e' },
  red:    { background: '#fee2e2', color: '#991b1b' },
  blue:   { background: '#dbeafe', color: '#1e40af' },
  gray:   { background: '#f3f4f6', color: '#374151' },
}

const CHALLENGE_COLORS: Record<number, string> = {
  [ChallengeState.CREATED]:   'green',
  [ChallengeState.ACCEPTED]:  'green',
  [ChallengeState.SUBMITTED]: 'yellow',
  [ChallengeState.DISPUTED]:  'red',
  [ChallengeState.RESOLVED]:  'yellow',
  [ChallengeState.FINALIZED]: 'blue',
  [ChallengeState.VOIDED]:    'gray',
}

const POOL_COLORS: Record<number, string> = {
  [PoolState.OPEN]:      'green',
  [PoolState.CLOSED]:    'gray',
  [PoolState.SUBMITTED]: 'yellow',
  [PoolState.DISPUTED]:  'red',
  [PoolState.FINALIZED]: 'blue',
  [PoolState.VOIDED]:    'gray',
}

export function ChallengeStateBadge({ state }: { state: number }) {
  const colorKey = CHALLENGE_COLORS[state] ?? 'gray'
  return (
    <span style={{ ...BADGE_STYLE_BASE, ...COLOR[colorKey] }}>
      {ChallengeState[state] ?? 'Unknown'}
    </span>
  )
}

export function PoolStateBadge({ state }: { state: number }) {
  const colorKey = POOL_COLORS[state] ?? 'gray'
  return (
    <span style={{ ...BADGE_STYLE_BASE, ...COLOR[colorKey] }}>
      {PoolState[state] ?? 'Unknown'}
    </span>
  )
}
