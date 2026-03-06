'use client'

import { useState, useEffect } from 'react'
import { formatCountdown } from '@/lib/utils'

export function Countdown({ expiresAt }: { expiresAt: bigint }) {
  const [text, setText] = useState(() => formatCountdown(expiresAt))

  useEffect(() => {
    const id = setInterval(() => {
      setText(formatCountdown(expiresAt))
    }, 60_000)
    return () => clearInterval(id)
  }, [expiresAt])

  if (text === 'Expired') {
    return <span className="text-red-500">{text}</span>
  }
  return <span>{text}</span>
}
