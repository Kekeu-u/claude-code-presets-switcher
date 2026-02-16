const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const DASHBOARD_PORT = 3456;
const CCR_HOST = '127.0.0.1';
const CCR_PORT = 3000;

const MIME = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

const server = http.createServer((req, res) => {
  // Proxy /api/* to CCR
  if (req.url.startsWith('/api/')) {
    const proxyOpts = {
      hostname: CCR_HOST,
      port: CCR_PORT,
      path: req.url,
      method: req.method,
      headers: {
        ...req.headers,
        host: `${CCR_HOST}:${CCR_PORT}`,
      },
    };

    const proxyReq = http.request(proxyOpts, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, {
        ...proxyRes.headers,
        'Access-Control-Allow-Origin': '*',
      });
      proxyRes.pipe(res);
    });

    proxyReq.on('error', (err) => {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'CCR not reachable', detail: err.message }));
    });

    req.pipe(proxyReq);
    return;
  }

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    res.end();
    return;
  }

  // Serve static files
  let filePath = req.url === '/' ? '/index.html' : req.url;
  filePath = path.join(__dirname, filePath);

  const ext = path.extname(filePath);
  const contentType = MIME[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
});

server.listen(DASHBOARD_PORT, () => {
  const url = `http://localhost:${DASHBOARD_PORT}`;
  console.log();
  console.log('  ⚡ CCR Dashboard running');
  console.log(`  🌐 ${url}`);
  console.log(`  🔀 Proxy → http://${CCR_HOST}:${CCR_PORT}`);
  console.log();
  console.log('  Press Ctrl+C to stop');
  console.log();

  // Auto-open browser
  if (process.platform === 'win32') exec(`start ${url}`);
  else if (process.platform === 'darwin') exec(`open ${url}`);
  else exec(`xdg-open ${url}`);
});
