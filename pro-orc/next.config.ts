import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // CRITICAL: prevents Next.js from bundling Node.js-native packages.
  // chokidar and simple-git are NOT in Next.js's default external list.
  // Without this, fsevents binary fails silently → polling at 100% CPU.
  serverExternalPackages: ['chokidar', 'simple-git', 'fsevents'],
}

export default nextConfig
