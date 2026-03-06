import type { Metadata } from 'next'
import { CreatePoolClient } from './CreatePoolClient'

export const metadata: Metadata = {
  title: 'Create Pool',
  description: 'Create a new prediction pool and stake USDC on an outcome.',
}

export default function CreatePoolPage() {
  return <CreatePoolClient />
}
