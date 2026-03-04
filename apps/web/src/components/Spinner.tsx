export function Spinner({ label = 'Loading…' }: { label?: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
      <style>{`
        @keyframes clout-spin {
          to { transform: rotate(360deg); }
        }
        .clout-spinner {
          width: 1.25rem;
          height: 1.25rem;
          border: 2px solid #ccc;
          border-top-color: #555;
          border-radius: 50%;
          animation: clout-spin 0.7s linear infinite;
          flex-shrink: 0;
        }
      `}</style>
      <div className="clout-spinner" aria-hidden="true" />
      <span>{label}</span>
    </div>
  )
}
