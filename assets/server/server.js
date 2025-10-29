import express from "express";
import { createProxyMiddleware } from "http-proxy-middleware";

const app = express();

app.use(
  "",
  createProxyMiddleware({
    target: "http://localhost:9222",
    changeOrigin: true,
    ws: true,
    secure: false,
    xfwd: true,
    onProxyReq: (proxyReq) => {
      // Trick Chrome into thinking it's localhost
      proxyReq.setHeader("Origin", "http://localhost:30001");
      proxyReq.setHeader("x-forwarded-host", "http://localhost:30001");
      proxyReq.setHeader("Host", "localhost:30001");
    },
  })
);

app.listen(30001, () => {
  console.log("Reverse proxy running on http://localhost:30001");
});