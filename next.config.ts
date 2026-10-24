import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The public/ dir carries multi-MB build outputs (Flutter web bundle,
  // APKs) that can crash the dev watcher; scripts/daemon.sh restarts it and
  // Next 18 will expose the turbopack watchOptions type used above.

};

export default nextConfig;
