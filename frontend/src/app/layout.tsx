import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Ember Lottery | Win ETH',
  description: 'Buy tickets, win the pot! 5% of fees support $EMBER stakers. Built by Ember 🐉',
  openGraph: {
    title: 'Ember Lottery 🎲',
    description: 'Buy tickets, win the pot! Built by Ember 🐉',
    images: ['/og.png'],
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={`${inter.className} bg-black text-white`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
