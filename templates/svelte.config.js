// Example SvelteKit configuration for static site generation
import adapter from "@sveltejs/adapter-static";

/** @type {import('@sveltejs/kit').Config} */
const config = {
  kit: {
    adapter: adapter({
      pages: 'build',       // Directory to output static pages
      assets: 'build',      // Directory to output assets
      fallback: 'index.html', // Fallback page for SPA routing
      precompress: false,
      strict: true
    }),
    paths: {
      base: '',
    },
    prerender: {
      entries: ['*'],
      handleHttpError: "warn",
    },
  },
};

export default config;
