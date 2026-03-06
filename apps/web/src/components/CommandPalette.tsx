'use client'

import { useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'

const NAV_ITEMS = [
  { label: 'Home',             href: '/' },
  { label: 'Challenges',       href: '/challenges' },
  { label: 'Pools',            href: '/pools' },
  { label: 'Faucet',           href: '/faucet' },
  { label: 'Create Challenge', href: '/challenges/create' },
  { label: 'Create Pool',      href: '/pools/create' },
]

export function CommandPalette({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter()
  const dialogRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [open, onClose])

  useEffect(() => {
    if (open) {
      dialogRef.current?.querySelector('button')?.focus()
    }
  }, [open])

  if (!open) return null

  return (
    <>
      <div
        style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 50 }}
        onClick={onClose}
        aria-hidden="true"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label="Command palette"
        ref={dialogRef}
        style={{
          position: 'fixed',
          top: '20%',
          left: '50%',
          transform: 'translateX(-50%)',
          zIndex: 51,
          background: 'var(--background)',
          border: '1px solid #ccc',
          borderRadius: '0.5rem',
          padding: '1rem',
          width: '20rem',
          maxWidth: '90vw',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <p style={{ marginBottom: '0.75rem', fontSize: '0.875rem', color: '#888' }}>Navigate to…</p>
        <ul role="list" style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: '0.25rem' }}>
          {NAV_ITEMS.map((item) => (
            <li key={item.href}>
              <button
                aria-label={`Go to ${item.label}`}
                onClick={() => { router.push(item.href); onClose() }}
                style={{ width: '100%', textAlign: 'left', padding: '0.5rem 0.75rem', borderRadius: '0.25rem', background: 'none', border: 'none', cursor: 'pointer' }}
              >
                {item.label}
              </button>
            </li>
          ))}
        </ul>
      </div>
    </>
  )
}
