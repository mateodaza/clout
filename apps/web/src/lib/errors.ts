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
