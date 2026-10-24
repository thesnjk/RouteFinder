import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Safe headers that do not break Vite HMR / React (strict CSP blanks the app in dev).
const securityHeaders = {
  'Referrer-Policy': 'no-referrer',
  'X-Content-Type-Options': 'nosniff',
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
