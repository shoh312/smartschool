import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Served from the public server under /web/ (and from the school server
// under the same path), so every asset URL is relative to that.
export default defineConfig({
  plugins: [react()],
  base: '/web/',
  build: { outDir: 'dist', sourcemap: false },
  server: { port: 5173 },
})
