import type { Metadata } from 'next'
import './globals.css'
import { Providers } from '@/components/Providers'
import { ConnectWallet } from '@/components/ConnectWallet'

export const metadata: Metadata = {
  title: 'Clout',
  description: 'The conviction market for the creator economy.',
}

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        <Providers>
          <header>
            <nav>
              <a href="/">Home</a>
              <a href="/challenges">Challenges</a>
              <a href="/pools">Pools</a>
              <ConnectWallet />
            </nav>
          </header>
          <main>{children}</main>
        </Providers>
      </body>
    </html>
  )
}
