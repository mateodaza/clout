import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const alt = 'Clout'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          background: '#111',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div style={{ color: '#fff', fontSize: 96, fontWeight: 'bold' }}>
          Clout
        </div>
        <div style={{ color: '#aaa', fontSize: 28, marginTop: 16 }}>
          The conviction market for the creator economy.
        </div>
      </div>
    ),
    { ...size },
  )
}
