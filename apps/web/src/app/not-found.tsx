import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="py-16 text-center">
      <p className="text-gray-400 text-sm mb-2">404</p>
      <h1 className="text-2xl font-semibold mb-3">Page not found</h1>
      <p className="text-gray-500 dark:text-gray-400 mb-6">
        The page you&apos;re looking for doesn&apos;t exist.
      </p>
      <Link
        href="/"
        aria-label="Go to homepage"
        className="inline-block px-4 py-2 border rounded text-sm hover:bg-gray-100 dark:hover:bg-gray-800 dark:border-gray-600"
      >
        Go to homepage
      </Link>
    </div>
  )
}
