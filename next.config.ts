const repo = "skylog";
const isProd = process.env.NODE_ENV === "production";
export default {
  output: "export",
  basePath: isProd ? `/${repo}` : "",
  assetPrefix: isProd ? `/${repo}/` : "",
  images: { unoptimized: true },
} as const;
