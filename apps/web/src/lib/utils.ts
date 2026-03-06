export function formatTimestamp(unix: bigint): string {
  if (unix === 0n) return '—'
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  }).format(new Date(Number(unix) * 1000))
}

export function formatCountdown(expiryUnix: bigint): string {
  const diffMs = Number(expiryUnix) * 1000 - Date.now()
  if (diffMs <= 0) return 'Expired'
  const totalMinutes = Math.floor(diffMs / 60000)
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  if (hours > 0) return `Expires in ${hours}h ${minutes}m`
  return `Expires in ${minutes}m`
}

export function formatBalance(raw: bigint): string {
  const formatted = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(raw) / 1_000_000)
  return `${formatted} mUSDC`
}
