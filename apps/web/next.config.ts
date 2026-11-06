import type { NextConfig } from 'next';

// Stage 1 has no server: the site is a static export, deployable to any static host.
const config: NextConfig = {
  output: 'export',
  transpilePackages: ['@shaxmat/chess-core'],
  reactStrictMode: true,
};

export default config;
