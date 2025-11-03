/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable standalone output for optimized Docker builds
  // This creates a minimal production build with only necessary dependencies
  output: 'standalone',

  // Server configuration
  // Note: In production, env vars are set via Kubernetes ConfigMap
  env: {
    LOCATION: process.env.LOCATION,
    BACKEND_URL: process.env.BACKEND_URL,
  },

  // Disable x-powered-by header for security
  poweredByHeader: false,

  // Strict mode for better development experience
  reactStrictMode: true,
}

export default nextConfig
