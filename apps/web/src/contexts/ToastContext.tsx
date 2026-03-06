'use client'

import { createContext, useCallback, useContext, useRef, useState } from 'react'

type ToastType = 'pending' | 'confirmed' | 'failed'

export interface Toast {
  id: string
  type: ToastType
  message: string
}

interface ToastContextValue {
  toasts: Toast[]
  addToast: (type: ToastType, message: string) => string
  updateToast: (id: string, type: ToastType, message: string) => void
  dismissToast: (id: string) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast must be used within ToastProvider')
  return ctx
}

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])
  const timers = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map())
  const counter = useRef<number>(0)

  const scheduleAutoDismiss = useCallback((id: string) => {
    const timer = setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id))
      timers.current.delete(id)
    }, 5000)
    timers.current.set(id, timer)
  }, [])

  const addToast = useCallback((type: ToastType, message: string): string => {
    const id = String(++counter.current)
    setToasts(prev => [...prev, { id, type, message }])
    if (type === 'confirmed') {
      scheduleAutoDismiss(id)
    }
    return id
  }, [scheduleAutoDismiss])

  const updateToast = useCallback((id: string, type: ToastType, message: string): void => {
    setToasts(prev => prev.map(t => t.id === id ? { ...t, type, message } : t))
    if (type === 'confirmed') {
      scheduleAutoDismiss(id)
    } else if (type === 'failed') {
      const existing = timers.current.get(id)
      if (existing) {
        clearTimeout(existing)
        timers.current.delete(id)
      }
    }
  }, [scheduleAutoDismiss])

  const dismissToast = useCallback((id: string): void => {
    const timer = timers.current.get(id)
    if (timer) {
      clearTimeout(timer)
      timers.current.delete(id)
    }
    setToasts(prev => prev.filter(t => t.id !== id))
  }, [])

  return (
    <ToastContext.Provider value={{ toasts, addToast, updateToast, dismissToast }}>
      {children}
    </ToastContext.Provider>
  )
}
