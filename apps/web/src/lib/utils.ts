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

export function formatCountdown(expiryUnix: bigint, prefix = 'Expires in'): string {
  const diffMs = Number(expiryUnix) * 1000 - Date.now()
  if (diffMs <= 0) return 'Expired'
  const totalMinutes = Math.floor(diffMs / 60000)
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  if (hours >= 24) {
    const days = Math.floor(hours / 24)
    const remainingHours = hours % 24
    return `${prefix} ${days}d ${remainingHours}h`
  }
  if (hours > 0) return `${prefix} ${hours}h ${minutes}m`
  return `${prefix} ${minutes}m`
}

export function formatBalance(raw: bigint): string {
  const formatted = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(raw) / 1_000_000)
  return `${formatted} mUSDC`
}

export function basescanUrl(type: 'address' | 'tx', value: string): string {
  const base = process.env.NEXT_PUBLIC_EXPLORER_URL ?? 'https://sepolia.basescan.org'
  return `${base}/${type === 'address' ? 'address' : 'tx'}/${value}`
}
