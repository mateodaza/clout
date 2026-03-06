import type { MetadataRoute } from 'next'

const BASE = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://clout.build'
const MAX_CHALLENGES = Number(process.env.NEXT_PUBLIC_SITEMAP_MAX_CHALLENGES ?? '0')
const MAX_POOLS = Number(process.env.NEXT_PUBLIC_SITEMAP_MAX_POOLS ?? '0')

export default function sitemap(): MetadataRoute.Sitemap {
  const staticRoutes: MetadataRoute.Sitemap = [
    { url: `${BASE}/`,                  changeFrequency: 'weekly',  priority: 1.0 },
    { url: `${BASE}/challenges`,         changeFrequency: 'hourly',  priority: 0.9 },
    { url: `${BASE}/challenges/create`,  changeFrequency: 'monthly', priority: 0.7 },
    { url: `${BASE}/pools`,              changeFrequency: 'hourly',  priority: 0.9 },
    { url: `${BASE}/pools/create`,       changeFrequency: 'monthly', priority: 0.7 },
  ]

  const challengeRoutes: MetadataRoute.Sitemap = Array.from(
    { length: MAX_CHALLENGES },
    (_, i) => ({
      url: `${BASE}/challenges/${i + 1}`,
      changeFrequency: 'daily' as const,
      priority: 0.6,
    }),
  )

  const poolRoutes: MetadataRoute.Sitemap = Array.from(
    { length: MAX_POOLS },
    (_, i) => ({
      url: `${BASE}/pools/${i + 1}`,
      changeFrequency: 'daily' as const,
      priority: 0.6,
    }),
  )

  return [...staticRoutes, ...challengeRoutes, ...poolRoutes]
}
