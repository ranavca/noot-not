import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    minify: 'esbuild'  // Use esbuild instead of terser (faster and built-in)
  },
  server: {
    host: '0.0.0.0',
    port: 3000
  }
})
