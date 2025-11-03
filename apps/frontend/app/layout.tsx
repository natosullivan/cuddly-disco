import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'cuddly-disco.ai',
  description: 'Encouraging messages for SREs everywhere',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
