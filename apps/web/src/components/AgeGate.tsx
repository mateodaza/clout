'use client'

import { useState, useEffect, useRef } from 'react'

export function AgeGate() {
  const [verified, setVerified] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false
    return localStorage.getItem('clout-age-verified') === 'true'
  })
  const confirmBtnRef = useRef<HTMLButtonElement>(null)
  const exitBtnRef    = useRef<HTMLButtonElement>(null)

  useEffect(() => {
    if (!verified) {
      confirmBtnRef.current?.focus()
    }
  }, [verified])

  useEffect(() => {
    if (!verified) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => { document.body.style.overflow = '' }
  }, [verified])

  useEffect(() => {
    if (verified) return

    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        e.preventDefault()
        e.stopPropagation()
        return
      }

      if (e.metaKey || e.ctrlKey || e.altKey) {
        e.preventDefault()
        e.stopPropagation()
        return
      }

      if (e.key === 'Tab') {
        e.preventDefault()
        const active = document.activeElement
        if (e.shiftKey) {
          if (active === confirmBtnRef.current) {
            exitBtnRef.current?.focus()
          } else {
            confirmBtnRef.current?.focus()
          }
        } else {
          if (active === exitBtnRef.current) {
            confirmBtnRef.current?.focus()
          } else {
            exitBtnRef.current?.focus()
          }
        }
        return
      }

      if (e.key === ' ' || e.key === 'Enter') return

      e.preventDefault()
      e.stopPropagation()
    }

    document.addEventListener('keydown', onKeyDown, { capture: true })
    return () => document.removeEventListener('keydown', onKeyDown, { capture: true })
  }, [verified])

  function handleConfirm() {
    localStorage.setItem('clout-age-verified', 'true')
    setVerified(true)
  }

  function handleExit() {
    window.location.href = 'https://www.google.com'
  }

  if (verified) return null

  return (
    <div
      suppressHydrationWarning
      style={{ position: 'fixed', inset: 0, zIndex: 100 }}
      className="flex items-center justify-center bg-black/80 backdrop-blur-sm"
    >
      <div className="bg-white dark:bg-gray-900 rounded-xl p-8 max-w-md w-full mx-4 shadow-2xl">
        <h2 className="text-xl font-semibold mb-3">Age Verification Required</h2>
        <p className="text-sm text-gray-600 dark:text-gray-300">
          You must be 18 or older to use Clout. This platform involves wagering
          with real digital assets.
        </p>
        <div className="flex gap-4 mt-6">
          <button
            ref={confirmBtnRef}
            onClick={handleConfirm}
            className="flex-1 py-2 px-4 bg-blue-600 text-white rounded font-medium hover:bg-blue-700"
          >
            I am 18+
          </button>
          <button
            ref={exitBtnRef}
            onClick={handleExit}
            className="flex-1 py-2 px-4 border rounded font-medium hover:bg-gray-50 dark:hover:bg-gray-800"
          >
            Exit
          </button>
        </div>
      </div>
    </div>
  )
}
