'use client'

import { useState, useEffect } from 'react'
import { formatCountdown } from '@/lib/utils'

interface CountdownProps {
  expiresAt: bigint
  prefix?: string
  expiredLabel?: string
}

export function Countdown({ expiresAt, prefix = 'Expires in', expiredLabel = 'Expired' }: CountdownProps) {
  const [text, setText] = useState(() => formatCountdown(expiresAt, prefix))

  useEffect(() => {
    const id = setInterval(() => {
      setText(formatCountdown(expiresAt, prefix))
    }, 60_000)
    return () => clearInterval(id)
  }, [expiresAt, prefix])

  if (text === 'Expired') {
    return <span className="text-red-500">{expiredLabel}</span>
  }
  return <span>{text}</span>
}
