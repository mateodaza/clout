/**
 * @clout/types — shared domain types for the Clout protocol.
 *
 * Contract enums/structs mirrored here so the frontend and backend
 * stay in sync without importing Solidity ABIs directly.
 */

// ---------------------------------------------------------------------------
// CloutEscrow types
// ---------------------------------------------------------------------------

export enum ChallengeState {
  CREATED = 0,
  ACCEPTED = 1,
  SUBMITTED = 2,
  DISPUTED = 3,
  RESOLVED = 4,
  FINALIZED = 5,
  VOIDED = 6,
}

export enum Outcome {
  NONE = 0,
  CREATOR_WIN = 1,
  OPPONENT_WIN = 2,
  DRAW = 3,
  INVALID = 4,
}

export interface Challenge {
  creator: string;
  opponent: string;
  designatedResolver: string;
  token: string;
  stakeAmount: bigint;
  state: ChallengeState;
  gameId: string;
  matchId: string;
  submittedResult: Outcome;
  submittedBy: string;
  createdAt: bigint;
  acceptedAt: bigint;
  submittedAt: bigint;
  disputedAt: bigint;
  resolvedAt: bigint;
  claimed: boolean;
  appealed: boolean;
  appealedAt: bigint;
}

export interface WalletRecord {
  challengesEntered: bigint;
  challengesCompleted: bigint;
  challengesWon: bigint;
  challengesDisputed: bigint;
  totalStaked: bigint;
  firstChallengeAt: bigint;
  lastChallengeAt: bigint;
}

// ---------------------------------------------------------------------------
// CloutPool types
// ---------------------------------------------------------------------------

export enum PoolState {
  OPEN = 0,
  CLOSED = 1,
  SUBMITTED = 2,
  DISPUTED = 3,
  FINALIZED = 4,
  VOIDED = 5,
}

export interface Pool {
  host: string;
  resolver: string;
  token: string;
  eventStart: bigint;
  eventEnd: bigint;
  resolveBy: bigint;
  perWalletCap: bigint;
  totalPoolCap: bigint;
  hostCommissionBps: bigint;
  state: PoolState;
  yesTotal: bigint;
  noTotal: bigint;
  resolvedAt: bigint;
  yesWins: boolean;
  losingStakerCount: bigint;
  flagCount: bigint;
}
