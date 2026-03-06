'use client'

import React from 'react'
import { friendlyError } from '@/lib/errors'

interface FallbackProps {
  error: Error | null
  reset: () => void
}

function ErrorFallback({ error, reset }: FallbackProps) {
  return (
    <div role="alert" className="border rounded p-4 my-4">
      <h2 className="font-semibold mb-2">Something went wrong</h2>
      <p className="mb-4 text-sm">{friendlyError(error)}</p>
      <button
        onClick={reset}
        aria-label="Try again — reload this section"
        className="px-4 py-2 border rounded text-sm hover:bg-gray-100 dark:hover:bg-gray-800"
      >
        Try again
      </button>
    </div>
  )
}

interface ErrorBoundaryProps {
  children: React.ReactNode
  fallback?: React.ReactNode
}

interface State {
  hasError: boolean
  error: Error | null
}

export class ErrorBoundary extends React.Component<ErrorBoundaryProps, State> {
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = { hasError: false, error: null }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, info: React.ErrorInfo): void {
    console.error('[ErrorBoundary]', error, info)
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback
      }
      return (
        <ErrorFallback
          error={this.state.error}
          reset={() => this.setState({ hasError: false, error: null })}
        />
      )
    }
    return this.props.children
  }
}
