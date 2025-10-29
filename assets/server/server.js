import express from "express";
import { createProxyMiddleware, responseInterceptor } from "http-proxy-middleware";

const app = express();

app.use(
  "",
  createProxyMiddleware({
    target: "http://localhost:9222",
    changeOrigin: true,
    ws: true,
    secure: false,
    xfwd: true,
    selfHandleResponse: true, // we want to modify the response
    on: {
      proxyReq: (proxyReq) => {
        // Trick Chrome into thinking it's localhost
        proxyReq.setHeader("Origin", "http://localhost:30001");
        proxyReq.setHeader("x-forwarded-host", "http://localhost:30001");
        proxyReq.setHeader("Host", "localhost:30001");
      },
      proxyRes: responseInterceptor(async (responseBuffer, proxyRes, req, res) => {
        const originHost = req.get("host") || req.get("x-forwarded-host") || "localhost:30001";
        const response = responseBuffer.toString("utf8"); // convert buffer to string
        return response.replace("localhost:30001", originHost); // manipulate response and return the result
      }),
    },
  })
);

app.listen(30001, () => {
  console.log("Reverse proxy running on http://localhost:30001");
});
