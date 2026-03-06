import { ChallengeState, PoolState } from '@clout/types'

const BASE_CLASS = 'inline-block rounded-full py-0.5 px-2.5 text-xs font-semibold'

const COLOR: Record<string, string> = {
  green:  'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300',
  yellow: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300',
  red:    'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300',
  blue:   'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300',
  gray:   'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-200',
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
    <span className={`${BASE_CLASS} ${COLOR[colorKey]}`}>
      {ChallengeState[state] ?? 'Unknown'}
    </span>
  )
}

export function PoolStateBadge({ state }: { state: number }) {
  const colorKey = POOL_COLORS[state] ?? 'gray'
  return (
    <span className={`${BASE_CLASS} ${COLOR[colorKey]}`}>
      {PoolState[state] ?? 'Unknown'}
    </span>
  )
}
