// Copies the single-threaded lite Stockfish build into public/ so the browser
// can load it as a Web Worker. Single-threaded = no COOP/COEP headers needed,
// so it works on any static host.
import { createRequire } from 'node:module';
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));
let pkgDir;
try {
  pkgDir = dirname(require.resolve('stockfish/package.json'));
} catch {
  console.warn('[copy-engine] stockfish package not installed yet, skipping');
  process.exit(0);
}

const out = join(here, '..', 'public', 'stockfish');
mkdirSync(out, { recursive: true });
for (const f of ['stockfish-19-lite-single.js', 'stockfish-19-lite-single.wasm']) {
  const dest = join(out, f);
  if (!existsSync(dest)) copyFileSync(join(pkgDir, 'bin', f), dest);
}
console.log('[copy-engine] engine ready in public/stockfish');
