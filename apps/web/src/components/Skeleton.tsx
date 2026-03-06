export function Skeleton({
  width,
  height,
  className = '',
}: {
  width?: string
  height?: string
  className?: string
}) {
  return (
    <div
      className={`animate-pulse bg-gray-200 rounded ${className}`}
      style={{ width, height }}
      aria-hidden="true"
    />
  )
}
