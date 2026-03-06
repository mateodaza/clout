'use client'

import { useToast, Toast } from '@/contexts/ToastContext'

export function ToastContainer() {
  const { toasts } = useToast()
  if (toasts.length === 0) return null
  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 w-80 pointer-events-none">
      {toasts.map(toast => (
        <ToastItem key={toast.id} toast={toast} />
      ))}
    </div>
  )
}

export function ToastItem({ toast }: { toast: Toast }) {
  const { dismissToast } = useToast()

  if (toast.type === 'pending') {
    return (
      <div className="pointer-events-auto flex items-center gap-3 rounded-lg border px-4 py-3 text-sm shadow-lg bg-yellow-50 border-yellow-300 text-yellow-800">
        <style>{`
          @keyframes toast-spin {
            to { transform: rotate(360deg); }
          }
          .toast-spinner {
            width: 1.25rem;
            height: 1.25rem;
            border: 2px solid #ccc;
            border-top-color: #555;
            border-radius: 50%;
            animation: toast-spin 0.7s linear infinite;
            flex-shrink: 0;
          }
        `}</style>
        <div className="toast-spinner" aria-hidden="true" />
        <span className="flex-1">{toast.message}</span>
      </div>
    )
  }

  if (toast.type === 'confirmed') {
    return (
      <div className="pointer-events-auto flex items-center gap-3 rounded-lg border px-4 py-3 text-sm shadow-lg bg-green-50 border-green-300 text-green-800">
        <span aria-hidden="true">✓</span>
        <span className="flex-1">{toast.message}</span>
      </div>
    )
  }

  // failed
  return (
    <div className="pointer-events-auto flex items-center gap-3 rounded-lg border px-4 py-3 text-sm shadow-lg bg-red-50 border-red-300 text-red-800">
      <span aria-hidden="true">✗</span>
      <span className="flex-1">{toast.message}</span>
      <button onClick={() => dismissToast(toast.id)} aria-label="Dismiss">×</button>
    </div>
  )
}
