// Slidev loads vite.config every root (theme roots + deck's own
// directory), not from repo root, so deck anywhere under talks/ would
// otherwise build with Vite 8's default cssMinify: lightningcss — fails
// parsing UnoCSS output ("Invalid token in pseudo element" on --un-* utilities).
// Re-export repo-root config single source truth.
export { default } from '../../vite.config.ts'
