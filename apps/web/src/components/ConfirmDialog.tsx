'use client'
import { useEffect, useRef } from 'react'

interface ConfirmDialogProps {
  title: string
  message: string
  onConfirm: () => void
  onCancel: () => void
}

export function ConfirmDialog({ title, message, onConfirm, onCancel }: ConfirmDialogProps) {
  const ref = useRef<HTMLDialogElement>(null)
  const intentRef = useRef(false)   // true when a button was explicitly clicked

  useEffect(() => {
    ref.current?.showModal()
    return () => { ref.current?.close() }
  }, [])

  return (
    <dialog
      ref={ref}
      onClose={() => { if (!intentRef.current) onCancel() }}
      className="rounded border p-6 max-w-sm w-full backdrop:bg-black/50"
    >
      <h2 className="font-semibold text-lg mb-2">{title}</h2>
      <p className="mb-6 text-sm">{message}</p>
      <div className="flex gap-3 justify-end">
        <button
          autoFocus
          onClick={() => { intentRef.current = true; onCancel() }}
          className="py-2 px-4 border rounded"
        >
          Cancel
        </button>
        <button
          onClick={() => { intentRef.current = true; onConfirm() }}
          className="py-2 px-4 border rounded"
        >
          Confirm
        </button>
      </div>
    </dialog>
  )
}
