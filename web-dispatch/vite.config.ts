import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const securityHeaders = {
  'Referrer-Policy': 'no-referrer',
  'X-Content-Type-Options': 'nosniff',
  // Desk is LAN/local; keep CSP strict enough to block accidental remote script injection.
  'Content-Security-Policy':
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; connect-src 'self' https: http://127.0.0.1:* http://localhost:* http://*.local:* ws://127.0.0.1:* ws://localhost:*; worker-src 'self' blob:; font-src 'self' data:",
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // MapLibre 6 resolves its worker via import.meta.url; prebundling breaks that path.
  optimizeDeps: {
    exclude: ['maplibre-gl'],
  },
  worker: {
    format: 'es',
  },
  server: {
    port: 5173,
    headers: securityHeaders,
    // Dev convenience: point base URL at http://127.0.0.1:5173/fleet and proxy to the LAN server.
    proxy: {
      '/fleet': {
        target: 'http://127.0.0.1:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/fleet/, ''),
      },
    },
  },
  preview: {
    headers: securityHeaders,
  },
})
