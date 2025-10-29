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
    onProxyRes: (proxyRes, req, res) => {
      // Intercept /json/version endpoint to modify webSocketDebuggerUrl
      if (req.url === '/json/version') {
        let body = '';
        proxyRes.on('data', (chunk) => {
          body += chunk;
        });
        
        proxyRes.on('end', () => {
          try {
            const data = JSON.parse(body);
            
            // Get the origin URL from the request
            const originHost = req.get('host') || req.get('x-forwarded-host') || 'localhost:30001';
            
            // Replace localhost in webSocketDebuggerUrl with the origin host
            if (data.webSocketDebuggerUrl) {
              data.webSocketDebuggerUrl = data.webSocketDebuggerUrl.replace('localhost:30001', originHost);
            }
            
            // Send the modified response
            res.writeHead(proxyRes.statusCode, {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Headers': '*'
            });
            res.end(JSON.stringify(data));
          } catch (error) {
            console.error('Error parsing /json/version response:', error);
            // If parsing fails, pass through the original response
            res.writeHead(proxyRes.statusCode, proxyRes.headers);
            res.end(body);
          }
        });
        
        // Don't write the original response body
        proxyRes.removeAllListeners('data');
        proxyRes.removeAllListeners('end');
      }
    },
  })
);

app.listen(30001, () => {
  console.log("Reverse proxy running on http://localhost:30001");
});