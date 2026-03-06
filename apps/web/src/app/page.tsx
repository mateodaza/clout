import type { Metadata } from 'next'
import { HomeClient } from './HomeClient'

export const metadata: Metadata = {
  title: 'Clout',
  description: 'The conviction market for the creator economy. Stake, compete, and prove your edge on-chain.',
  alternates: { canonical: '/' },
}

export default function HomePage() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            '@context': 'https://schema.org',
            '@type': 'WebApplication',
            name: 'Clout',
            description: 'The conviction market for the creator economy. Stake, compete, and prove your edge on-chain.',
            url: process.env.NEXT_PUBLIC_APP_URL ?? 'https://clout.app',
            applicationCategory: 'FinanceApplication',
            operatingSystem: 'Web',
          }),
        }}
      />
      <HomeClient />
    </>
  )
}
