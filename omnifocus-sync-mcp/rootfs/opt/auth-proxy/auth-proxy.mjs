import http from 'node:http';
import crypto from 'node:crypto';
import httpProxy from 'http-proxy';

const AUTH_MODE = process.env.AUTH_MODE || 'none';
const BEARER_TOKEN = process.env.BEARER_TOKEN || '';
const OAUTH2_INTROSPECTION_URL = process.env.OAUTH2_INTROSPECTION_URL || '';
const OAUTH2_INTROSPECTION_AUTH_HEADER = process.env.OAUTH2_INTROSPECTION_AUTH_HEADER || '';
const UPSTREAM_PORT = process.env.UPSTREAM_PORT || '8643';
const LISTEN_PORT = Number(process.env.LISTEN_PORT || '8642');
const LISTEN_HOST = process.env.LISTEN_HOST || '0.0.0.0';

const proxy = httpProxy.createProxyServer({
  target: `http://127.0.0.1:${UPSTREAM_PORT}`,
  ws: true,
  xfwd: true,
});

proxy.on('error', (err, req, res) => {
  console.error('[auth-proxy] upstream proxy error:', err.message);
  if (res && typeof res.writeHead === 'function' && !res.headersSent) {
    res.writeHead(502, { 'Content-Type': 'text/plain' });
    res.end('Bad Gateway: omnifocus-sync-mcp is not ready yet');
  } else if (res && typeof res.destroy === 'function') {
    res.destroy();
  }
});

function extractBearerToken(req) {
  const header = req.headers['authorization'] || '';
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1] : null;
}

// Constant-time comparison that doesn't short-circuit on length mismatch,
// so response timing doesn't leak how much of the token was correct.
function safeEqual(a, b) {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) {
    crypto.timingSafeEqual(bufA, Buffer.alloc(bufA.length));
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

function checkBearer(req) {
  const token = extractBearerToken(req);
  if (!token) return false;
  return safeEqual(token, BEARER_TOKEN);
}

// RFC 7662 OAuth 2.0 Token Introspection.
async function checkOauth2Introspection(req) {
  const token = extractBearerToken(req);
  if (!token) return false;
  try {
    const headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    };
    if (OAUTH2_INTROSPECTION_AUTH_HEADER) {
      headers['Authorization'] = OAUTH2_INTROSPECTION_AUTH_HEADER;
    }
    const response = await fetch(OAUTH2_INTROSPECTION_URL, {
      method: 'POST',
      headers,
      body: new URLSearchParams({ token, token_type_hint: 'access_token' }),
    });
    if (!response.ok) return false;
    const data = await response.json();
    return Boolean(data && data.active === true);
  } catch (err) {
    console.error('[auth-proxy] introspection request failed:', err.message);
    return false;
  }
}

async function isAuthorized(req) {
  switch (AUTH_MODE) {
    case 'bearer':
      return checkBearer(req);
    case 'oauth2_introspection':
      return checkOauth2Introspection(req);
    case 'none':
    default:
      return true;
  }
}

function writeUnauthorized(res) {
  res.writeHead(401, {
    'Content-Type': 'text/plain',
    'WWW-Authenticate': 'Bearer realm="omnifocus-sync-mcp"',
  });
  res.end('Unauthorized');
}

const server = http.createServer(async (req, res) => {
  if (!(await isAuthorized(req))) {
    writeUnauthorized(res);
    return;
  }
  proxy.web(req, res);
});

// MCP streamable-HTTP doesn't use WebSocket, but handle upgrades the same
// way in case a future transport (or a client's own tooling) does.
server.on('upgrade', async (req, socket, head) => {
  if (!(await isAuthorized(req))) {
    socket.write(
      'HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Bearer realm="omnifocus-sync-mcp"\r\n\r\n',
    );
    socket.destroy();
    return;
  }
  proxy.ws(req, socket, head);
});

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(
    `[auth-proxy] listening on ${LISTEN_HOST}:${LISTEN_PORT}, auth_mode=${AUTH_MODE}, upstream=127.0.0.1:${UPSTREAM_PORT}`,
  );
});
