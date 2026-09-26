import path from 'node:path';

import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  base: '/',
  plugins: [react()],
  // Netlify supplies COMMIT_REF for Git builds; a local build is marked as unknown.
  define: {
    __BUILD_COMMIT__: JSON.stringify(process.env.COMMIT_REF ?? process.env.GITHUB_SHA ?? ''),
  },
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, 'src'),
    },
  },
});
