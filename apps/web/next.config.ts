import type { NextConfig } from 'next';

// Static export: the site needs no server and can be hosted anywhere.
const config: NextConfig = {
  output: 'export',
  transpilePackages: ['@shaxmat/chess-core'],
  reactStrictMode: true,
};

export default config;
