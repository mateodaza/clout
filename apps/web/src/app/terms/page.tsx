import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Terms of Use',
  description: 'Clout Terms of Use — placeholder structure.',
  alternates: { canonical: '/terms' },
}

export default function TermsPage() {
  return (
    <div className="max-w-2xl">
      <h1>Terms of Use</h1>
      <p className="text-sm text-gray-500 mt-2 mb-8">
        Placeholder — not legal advice. Updated before mainnet launch.
      </p>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">1. Overview</h2>
        <p className="text-sm">Clout is a skill-based competition platform ...</p>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">2. Eligibility</h2>
        <p className="text-sm">You must be 18+ and ensure use is legal in your jurisdiction ...</p>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">3. Risk Disclosure</h2>
        <p className="text-sm">You may lose staked tokens. Only stake what you can afford to lose ...</p>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">4. Not Financial Advice</h2>
        <p className="text-sm">Nothing here is financial, legal, or investment advice ...</p>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">5. Smart Contract Risk</h2>
        <p className="text-sm">Contracts may contain bugs. Clout is not responsible for losses due to contract failures ...</p>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">6. Responsible Gaming</h2>
        <p className="text-sm">Please wager responsibly. Seek professional help if needed ...</p>
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">7. Changes to Terms</h2>
        <p className="text-sm">These terms will be replaced with legally reviewed content before mainnet launch ...</p>
      </section>
    </div>
  )
}
