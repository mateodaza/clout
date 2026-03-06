import type { Metadata } from 'next'
import './globals.css'
import { Providers } from '@/components/Providers'
import { ConnectWallet } from '@/components/ConnectWallet'

export const metadata: Metadata = {
  title: { default: 'Clout', template: '%s | Clout' },
  description: 'The conviction market for the creator economy. Stake, compete, and prove your edge on-chain.',
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
    <html lang="en">
      <body>
        <Providers>
          <header className="border-b px-4 py-3">
            <nav className="flex flex-wrap items-center gap-x-4 gap-y-2">
              <a href="/" className="font-semibold">Clout</a>
              <a href="/challenges">Challenges</a>
              <a href="/pools">Pools</a>
              <a href="/faucet">Faucet</a>
              <div className="ml-auto">
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
