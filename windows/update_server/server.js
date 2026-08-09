/**
 * Disk Cleaner Windows Auto-Update Server
 * Built by Dyuthi Tech Solutions
 * 
 * Usage:
 *   node server.js
 * 
 * Endpoint:
 *   GET /api/update/version.json
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const VERSION_FILE = path.join(__dirname, 'version.json');

const server = http.createServer((req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.url === '/api/update/version.json' || req.url === '/version.json') {
    if (fs.existsSync(VERSION_FILE)) {
      const data = fs.readFileSync(VERSION_FILE, 'utf8');
      res.writeHead(200);
      res.end(data);
    } else {
      res.writeHead(404);
      res.end(JSON.stringify({ error: 'Version file not found' }));
    }
  } else {
    res.writeHead(200);
    res.end(JSON.stringify({ message: 'Disk Cleaner Windows Auto-Update Server Running' }));
  }
});

server.listen(PORT, () => {
  console.log(`===================================================`);
  console.log(`  Disk Cleaner Windows Auto-Update Server`);
  console.log(`  Running on http://localhost:${PORT}/api/update/version.json`);
  console.log(`===================================================`);
});
