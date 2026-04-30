/** @type {import('next').NextConfig} */
const nextConfig = {
  allowedDevOrigins: ["psy.heyturgay.com"],
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "picsum.photos" },
    ],
  },
};

module.exports = nextConfig;
