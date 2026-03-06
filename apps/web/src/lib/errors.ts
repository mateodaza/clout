import { BaseError, ContractFunctionRevertedError } from 'viem'

export function parseRevertReason(err: Error | null | undefined): string {
  if (!err) return 'Unknown error'
  if (err instanceof BaseError) {
    const revert = err.walk((e) => e instanceof ContractFunctionRevertedError)
    if (revert instanceof ContractFunctionRevertedError) {
      return revert.reason ?? revert.shortMessage ?? err.shortMessage
    }
    return err.shortMessage ?? err.message
  }
  return err.message
}

export function friendlyError(err: Error | null | undefined): string {
  if (!err) return 'Unknown error'

  const msg = err.message?.toLowerCase() ?? ''
  const short = ('shortMessage' in err ? (err as BaseError).shortMessage : '')?.toLowerCase() ?? ''
  const code = 'code' in err ? (err as { code?: number }).code : undefined

  if (
    code === 4001 ||
    msg.includes('user rejected') ||
    msg.includes('user denied') ||
    msg.includes('rejected the request') ||
    short.includes('user rejected') ||
    short.includes('user denied') ||
    short.includes('rejected the request')
  ) {
    return 'Transaction cancelled.'
  }

  if (
    msg.includes('insufficient funds') ||
    msg.includes('insufficient eth') ||
    short.includes('insufficient funds') ||
    short.includes('insufficient eth')
  ) {
    return 'Insufficient funds for gas fees. Please add ETH to your wallet.'
  }

  if (
    msg.includes('execution reverted') ||
    msg.includes('reverted') ||
    short.includes('execution reverted') ||
    short.includes('reverted')
  ) {
    const reason = parseRevertReason(err)
    if (reason && reason !== 'Unknown error') {
      return `Transaction failed: ${reason}`
    }
    return 'Transaction failed. The contract rejected this action.'
  }

  if (
    msg.includes('network') ||
    msg.includes('could not connect') ||
    short.includes('network') ||
    short.includes('could not connect')
  ) {
    return 'Network error. Please check your connection and try again.'
  }

  return parseRevertReason(err)
}
