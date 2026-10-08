'use strict';

// Serve somente o build demo no loopback; nunca exponha a raiz do projeto.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const port = Number(process.argv[2] || 17360);
if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  throw new Error('Informe uma porta entre 1024 e 65535.');
}
if (!fs.existsSync(path.join(root, 'index.html'))) {
  throw new Error('Compile o Flutter web demo antes de iniciar o servidor.');
}
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.svg': 'image/svg+xml' };
http.createServer((request, response) => {
  if (!['GET', 'HEAD'].includes(request.method)) {
    response.writeHead(405).end(); return;
  }
  let file;
  try {
    const route = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    file = path.resolve(root, '.' + (route === '/' ? '/index.html' : route));
  } catch {
    response.writeHead(400).end(); return;
  }
  const relative = path.relative(root, file);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    response.writeHead(403).end(); return;
  }
  fs.stat(file, (error, stat) => {
    if (error || !stat.isFile()) { response.writeHead(404).end(); return; }
    response.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store' });
    if (request.method === 'HEAD') { response.end(); return; }
    const stream = fs.createReadStream(file);
    stream.on('error', () => response.destroy());
    stream.pipe(response);
  });
}).listen(port, '127.0.0.1', () => {
  console.log(`Build web em http://127.0.0.1:${port}; Ctrl+C encerra.`);
});
