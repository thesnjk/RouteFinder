import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Dev convenience: point base URL at http://127.0.0.1:5173/fleet and proxy to the LAN server.
    proxy: {
      '/fleet': {
        target: 'http://127.0.0.1:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/fleet/, ''),
      },
    },
  },
})
