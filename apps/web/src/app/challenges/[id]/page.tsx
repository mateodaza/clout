import type { Metadata } from 'next'
import { ChallengeDetailClient } from './ChallengeDetailClient'

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>
}): Promise<Metadata> {
  const { id } = await params
  return {
    title: `Challenge #${id}`,
    description: `View details and take actions on Challenge #${id} on Clout.`,
  }
}

export default function ChallengeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  return <ChallengeDetailClient params={params} />
}
