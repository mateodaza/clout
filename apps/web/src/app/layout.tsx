import type { Metadata } from 'next'
import './globals.css'
import { Providers } from '@/components/Providers'
import { ConnectWallet } from '@/components/ConnectWallet'
import { ThemeToggle } from '@/components/ThemeToggle'

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? 'https://clout.app'),
  title: { default: 'Clout', template: '%s | Clout' },
  description: 'The conviction market for the creator economy. Stake, compete, and prove your edge on-chain.',
  alternates: { canonical: '/' },
  openGraph: {
    title: 'Clout',
    description: 'The conviction market for the creator economy. Stake, compete, and prove your edge on-chain.',
    type: 'website',
  },
}

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){var t=localStorage.getItem('clout:theme');if(t==='dark'||(!t&&window.matchMedia('(prefers-color-scheme: dark)').matches)){document.documentElement.classList.add('dark');}})();`,
          }}
        />
      </head>
      <body>
        <Providers>
          <header className="border-b dark:border-gray-700 px-4 py-3">
            <nav className="flex flex-wrap items-center gap-x-4 gap-y-2">
              <a href="/" className="font-semibold" aria-label="Go to home">Clout</a>
              <a href="/challenges" aria-label="Go to challenges">Challenges</a>
              <a href="/pools" aria-label="Go to pools">Pools</a>
              <a href="/faucet" aria-label="Go to faucet">Faucet</a>
              <div className="ml-auto flex items-center gap-2">
                <ThemeToggle />
                <ConnectWallet />
              </div>
            </nav>
          </header>
          <main className="px-4 py-6 max-w-4xl mx-auto">{children}</main>
        </Providers>
      </body>
    </html>
  )
}
