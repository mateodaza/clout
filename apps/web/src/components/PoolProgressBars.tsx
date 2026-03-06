interface PoolProgressBarsProps {
  yesTotal: bigint
  noTotal: bigint
  totalPoolCap: bigint
  perWalletCap: bigint
  userYesStake: bigint
  userNoStake: bigint
  isConnected: boolean
}

function formatUsdc(amount: bigint): string {
  return (Number(amount) / 1_000_000).toFixed(2) + ' USDC'
}

export function PoolProgressBars({
  yesTotal,
  noTotal,
  totalPoolCap,
  perWalletCap,
  userYesStake,
  userNoStake,
  isConnected,
}: PoolProgressBarsProps) {
  // Bar 1 — YES/NO split
  const grandTotal = yesTotal + noTotal
  const yesPercent = grandTotal === 0n ? 0 : Number(yesTotal * 100n / grandTotal)
  const noPercent = grandTotal === 0n ? 0 : 100 - yesPercent

  // Bar 2 — Total pool fill
  const totalStaked = yesTotal + noTotal
  const fillPercent = totalPoolCap === 0n ? null : Math.min(100, Number(totalStaked * 100n / totalPoolCap))

  // Bar 3 — Per-wallet usage
  const userTotal = userYesStake + userNoStake
  const usedPercent = (!isConnected || perWalletCap === 0n) ? null : Math.min(100, Number(userTotal * 100n / perWalletCap))

  return (
    <div className="flex flex-col gap-4 my-6">
      {/* Bar 1 — YES/NO split */}
      <div>
        <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">
          {yesPercent}% YES / {noPercent}% NO
        </div>
        <div className="w-full h-4 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden flex">
          <div className="bg-green-500 h-full" style={{ width: `${yesPercent}%` }} />
          <div className="bg-red-500 h-full" style={{ width: `${noPercent}%` }} />
        </div>
      </div>

      {/* Bar 2 — Total pool fill */}
      {fillPercent !== null && (
        <div>
          <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">
            {fillPercent}% filled ({formatUsdc(totalStaked)} / {formatUsdc(totalPoolCap)})
          </div>
          <div className="w-full h-4 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden flex">
            <div className="bg-blue-500 h-full transition-all" style={{ width: `${fillPercent}%` }} />
          </div>
        </div>
      )}

      {/* Bar 3 — Per-wallet usage */}
      {usedPercent !== null && (
        <div>
          <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">
            {usedPercent}% of your cap used ({formatUsdc(userTotal)} / {formatUsdc(perWalletCap)})
          </div>
          <div className="w-full h-4 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden flex">
            <div className="bg-blue-500 h-full transition-all" style={{ width: `${usedPercent}%` }} />
          </div>
        </div>
      )}
    </div>
  )
}
