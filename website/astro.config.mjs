import { defineConfig } from 'astro/config';
import expressiveCode from 'astro-expressive-code';

export default defineConfig({
  site: 'https://dewdrop.dev',
  output: 'static',
  integrations: [
    expressiveCode({
      themes: ['github-dark'],
      styleOverrides: {
        borderRadius: '0',
        borderWidth: '0',
        codeFontFamily:
          '"IBM Plex Mono", ui-monospace, "SFMono-Regular", "SF Mono", Consolas, "Liberation Mono", monospace',
        frames: {
          frameBoxShadowCssValue: 'none',
          editorActiveTabBackground: 'oklch(20% 0.045 205)',
          editorActiveTabForeground: 'oklch(91% 0.035 178)',
          editorTabBarBackground: 'oklch(13% 0.035 205)',
        },
      },
    }),
  ],
});
