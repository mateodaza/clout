'use client'

import { useState } from 'react'

interface ShareButtonsProps {
  tweetText: string
}

export default function ShareButtons({ tweetText }: ShareButtonsProps) {
  const [copied, setCopied] = useState(false)

  function handleCopy() {
    navigator.clipboard.writeText(window.location.href)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  function handleShare() {
    const url = `https://twitter.com/intent/tweet?text=${encodeURIComponent(tweetText)}&url=${encodeURIComponent(window.location.href)}`
    window.open(url, '_blank', 'noopener,noreferrer')
  }

  return (
    <div className="flex gap-2 mt-2">
      <button onClick={handleCopy} aria-label={copied ? 'Link copied to clipboard' : 'Copy link to clipboard'}>
        {copied ? 'Copied!' : 'Copy Link'}
      </button>
      <button onClick={handleShare} aria-label="Share on X (Twitter)">Share on X</button>
    </div>
  )
}
