const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const DASHBOARD_HOST = '127.0.0.1';
const DASHBOARD_PORT = Number(process.env.CCR_DASHBOARD_PORT || 3456);
const CCR_HOST = process.env.CCR_HOST || '127.0.0.1';
const CCR_PORT = Number(process.env.CCR_PORT || 3000);
const PROXY_TIMEOUT_MS = Number(process.env.CCR_PROXY_TIMEOUT_MS || 15000);
const STATIC_ROOT = path.resolve(__dirname);

const MIME = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain',
};

function baseSecurityHeaders() {
  return {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
    'Cross-Origin-Resource-Policy': 'same-origin',
    'Cross-Origin-Opener-Policy': 'same-origin',
  };
}

function sendJson(res, status, payload, extraHeaders = {}) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    ...baseSecurityHeaders(),
    ...extraHeaders,
  });
  res.end(JSON.stringify(payload));
}

function resolveStaticPath(requestUrl) {
  const urlPath = (requestUrl || '/').split('?')[0];
  let decodedPath;
  try {
    decodedPath = decodeURIComponent(urlPath);
  } catch {
    return null;
  }

  const normalized = path.posix.normalize(decodedPath.startsWith('/') ? decodedPath : `/${decodedPath}`);
  const targetPath = normalized === '/' ? '/index.html' : normalized;
  const relativePath = targetPath.replace(/^\/+/, '');
  const absolutePath = path.resolve(STATIC_ROOT, relativePath);

  if (absolutePath !== STATIC_ROOT && !absolutePath.startsWith(`${STATIC_ROOT}${path.sep}`)) {
    return null;
  }

  return absolutePath;
}

function proxyToCcr(req, res) {
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
    res.writeHead(proxyRes.statusCode || 502, {
      ...proxyRes.headers,
      ...baseSecurityHeaders(),
      'Access-Control-Allow-Origin': '*',
    });
    proxyRes.pipe(res);
  });

  proxyReq.setTimeout(PROXY_TIMEOUT_MS, () => {
    proxyReq.destroy(new Error(`CCR request timeout after ${PROXY_TIMEOUT_MS}ms`));
  });

  proxyReq.on('error', (err) => {
    sendJson(
      res,
      502,
      { error: 'CCR not reachable', detail: err.message },
      { 'Access-Control-Allow-Origin': '*' }
    );
  });

  req.pipe(proxyReq);
}

const server = http.createServer((req, res) => {
  if (!req.url) {
    sendJson(res, 400, { error: 'Missing request URL' });
    return;
  }

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      ...baseSecurityHeaders(),
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    res.end();
    return;
  }

  // Proxy /api/* to CCR
  if (req.url.startsWith('/api/')) {
    proxyToCcr(req, res);
    return;
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    sendJson(res, 405, { error: 'Method not allowed' });
    return;
  }

  const filePath = resolveStaticPath(req.url);
  if (!filePath) {
    sendJson(res, 403, { error: 'Forbidden path' });
    return;
  }

  // Serve static files
  const ext = path.extname(filePath);
  const contentType = MIME[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, {
        ...baseSecurityHeaders(),
        'Content-Type': 'text/plain; charset=utf-8',
      });
      res.end('Not found');
      return;
    }

    res.writeHead(200, {
      ...baseSecurityHeaders(),
      'Content-Type': contentType,
    });

    if (req.method === 'HEAD') {
      res.end();
      return;
    }

    res.end(data);
  });
});

server.listen(DASHBOARD_PORT, DASHBOARD_HOST, () => {
  const url = `http://${DASHBOARD_HOST}:${DASHBOARD_PORT}`;
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

function shutdown() {
  server.close(() => process.exit(0));
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
