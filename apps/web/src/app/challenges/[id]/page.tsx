import type { Metadata } from 'next'
import { ChallengeDetailClient } from './ChallengeDetailClient'
import { ErrorBoundary } from '@/components/ErrorBoundary'

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>
}): Promise<Metadata> {
  const { id } = await params
  return {
    title: `Challenge #${id}`,
    description: `View details and take actions on Challenge #${id} on Clout.`,
    alternates: { canonical: `/challenges/${id}` },
  }
}

export default function ChallengeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  return (
    <ErrorBoundary>
      <ChallengeDetailClient params={params} />
    </ErrorBoundary>
  )
}
