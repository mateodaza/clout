'use client'

import { useEffect } from 'react'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div className="py-16 text-center">
      <h1 className="text-2xl font-semibold mb-3">Something went wrong</h1>
      <p className="text-gray-500 dark:text-gray-400 mb-6">
        {error.message || 'An unexpected error occurred.'}
      </p>
      <button
        onClick={reset}
        aria-label="Try again — reload the page"
        className="px-4 py-2 border rounded text-sm hover:bg-gray-100 dark:hover:bg-gray-800 dark:border-gray-600"
      >
        Try again
      </button>
    </div>
  )
}
