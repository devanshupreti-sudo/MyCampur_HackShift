import type { NextConfig } from "next";
const nextConfig: NextConfig = { reactStrictMode: true, distDir: ".next-build", experimental: { cpus: 1 } };
export default nextConfig;
