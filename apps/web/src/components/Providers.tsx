'use client'

import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { wagmiConfig } from '@/lib/wagmi'
import { useState, useEffect, useCallback } from 'react'
import { ToastProvider } from '@/contexts/ToastContext'
import { ToastContainer } from '@/components/Toast'
import { ThemeProvider } from '@/contexts/ThemeContext'
import { CommandPalette } from '@/components/CommandPalette'
import { AgeGate } from '@/components/AgeGate'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient())
  const [paletteOpen, setPaletteOpen] = useState(false)
  const handleClose = useCallback(() => setPaletteOpen(false), [])

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setPaletteOpen(o => !o)
      }
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [])

  return (
    <ThemeProvider>
      <WagmiProvider config={wagmiConfig}>
        <QueryClientProvider client={queryClient}>
          <ToastProvider>
            {children}
            <ToastContainer />
            <CommandPalette open={paletteOpen} onClose={handleClose} />
            <AgeGate />
          </ToastProvider>
        </QueryClientProvider>
      </WagmiProvider>
    </ThemeProvider>
  )
}
