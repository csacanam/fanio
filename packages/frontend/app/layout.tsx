import type { Metadata } from 'next'
import { GeistSans } from 'geist/font/sans'
import { GeistMono } from 'geist/font/mono'
import { Analytics } from '@vercel/analytics/next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Fanio - From Fans to Stakeholders',
  description: 'Trustless crowdfunding for live events powered by Uniswap v4 hooks. Fund concerts, earn tokens, enjoy exclusive perks.',
  keywords: ['blockchain', 'crowdfunding', 'concerts', 'events', 'defi', 'uniswap', 'tokens'],
  authors: [{ name: 'Fanio Team' }],
  creator: 'Fanio',
  publisher: 'Fanio',
  openGraph: {
    title: 'Fanio - From Fans to Stakeholders',
    description: 'Help make concerts happen and earn tradeable tokens with exclusive perks.',
    url: 'https://fanio.io',
    siteName: 'Fanio',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Fanio - From Fans to Stakeholders',
    description: 'Help make concerts happen and earn tradeable tokens with exclusive perks.',
    creator: '@fanio_io',
  },
  icons: {
    icon: '/favicon.ico',
    shortcut: '/favicon-16x16.png',
    apple: '/apple-touch-icon.png',
  },
  manifest: '/site.webmanifest',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body className={`font-sans ${GeistSans.variable} ${GeistMono.variable}`}>
        {children}
        <Analytics />
      </body>
    </html>
  )
}
