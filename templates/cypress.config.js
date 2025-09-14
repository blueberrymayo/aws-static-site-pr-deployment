import { defineConfig } from 'cypress'

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:4173',
    supportFile: 'tests/support/e2e.js',
    specPattern: 'tests/e2e/**/*.cy.js',
    videosFolder: 'tests/videos',
    screenshotsFolder: 'tests/screenshots',
    video: true,
    screenshotOnRunFailure: true,
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    responseTimeout: 10000,
    viewportWidth: 1280,
    viewportHeight: 720
  }
})
