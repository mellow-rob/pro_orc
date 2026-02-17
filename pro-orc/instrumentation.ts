// Singleton watcher bootstrap — runs once at Next.js server startup.
// The NEXT_RUNTIME guard ensures chokidar only loads in the Node.js runtime
// (not Edge runtime), since chokidar uses native Node.js APIs.
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    await import('./lib/watcher')
  }
}
