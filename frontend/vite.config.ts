import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  define: {
    'process.env.NODE_ENV': JSON.stringify('production'),
  },
  build: {
    lib: {
      entry: resolve(__dirname, 'src/app.ts'),
      name: 'LutamlUmlSpa',
      formats: ['iife'],
      fileName: () => 'app.iife.js',
    },
    rollupOptions: {
      external: [],
      output: {
        assetFileNames: 'style.[ext]',
      },
    },
    outDir: 'dist',
    emptyOutDir: true,
  },
})
