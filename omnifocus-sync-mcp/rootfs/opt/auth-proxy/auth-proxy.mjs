import http from 'node:http';
import crypto from 'node:crypto';
import httpProxy from 'http-proxy';

const AUTH_MODE = process.env.AUTH_MODE || 'none';
const BEARER_TOKEN = process.env.BEARER_TOKEN || '';
const OAUTH2_INTROSPECTION_URL = process.env.OAUTH2_INTROSPECTION_URL || '';
const OAUTH2_INTROSPECTION_AUTH_HEADER = process.env.OAUTH2_INTROSPECTION_AUTH_HEADER || '';
const UPSTREAM_PORT = process.env.UPSTREAM_PORT || '8643';
const CONFIGURED_LISTEN_PORT = Number(process.env.LISTEN_PORT || '8642');

// listen_address is meant to be a bare host/IP, but accept "host:port" and
// "[ipv6]:port" too, since that's an easy mistake to make. The internal
// container port can't actually change, though: it's fixed at build time
// by config.yaml's `ports`/`ingress_port` (both Home Assistant's ingress
// panel and the host port mapping target that fixed container port), so a
// port embedded here is parsed out only to warn about and then discarded
// -- never passed to server.listen, which would otherwise silently break
// ingress and the host port mapping. Use Supervisor's own Network tab for
// this add-on to remap the *external/host* port instead.
function parseListenHost(raw) {
  const value = (raw || '').trim();
  if (!value) return { host: '0.0.0.0', embeddedPort: null };

  const bracketed = /^\[(.+)\](?::(\d+))?$/.exec(value);
  if (bracketed) {
    return { host: bracketed[1], embeddedPort: bracketed[2] || null };
  }

  // A bare (non-bracketed) IPv6 address has 2+ colons; only split on a
  // single trailing ":<port>" so we don't mangle raw IPv6 literals.
  const colonCount = (value.match(/:/g) || []).length;
  if (colonCount === 1) {
    const [host, maybePort] = value.split(':');
    if (/^\d+$/.test(maybePort)) {
      return { host, embeddedPort: maybePort };
    }
  }

  return { host: value, embeddedPort: null };
}

const { host: LISTEN_HOST, embeddedPort } = parseListenHost(process.env.LISTEN_HOST);
const LISTEN_PORT = CONFIGURED_LISTEN_PORT;

if (embeddedPort && Number(embeddedPort) !== LISTEN_PORT) {
  console.warn(
    `[auth-proxy] listen_address included a port (:${embeddedPort}), which is ignored — ` +
      `the internal container port is fixed at ${LISTEN_PORT} by config.yaml. ` +
      `To use a different external port, remap it from this add-on's Network settings ` +
      `in Home Assistant instead of changing listen_address.`,
  );
}

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

server.on('error', (err) => {
  if (err.code === 'EADDRNOTAVAIL') {
    console.error(
      `[auth-proxy] Cannot bind to ${LISTEN_HOST}:${LISTEN_PORT}: this address isn't owned by ` +
        `any network interface inside this add-on's own container.\n` +
        `Under Home Assistant's default (bridge) add-on networking, a LAN address owned by the ` +
        `Supervisor *host* itself (like ${LISTEN_HOST}) is never reachable from inside the ` +
        `container — only "0.0.0.0" (all of the container's own interfaces) or the container's ` +
        `own internal Docker bridge address can be bound here. Binding directly to a host-owned ` +
        `LAN address would require this add-on to run with Home Assistant's host networking mode, ` +
        `which it does not currently support.\n` +
        `Set listen_address back to "0.0.0.0" (the default) — the add-on is already reachable on ` +
        `your LAN through Home Assistant's own port mapping / Network settings without needing a ` +
        `specific bind address.`,
    );
  } else {
    console.error(`[auth-proxy] Failed to start listening on ${LISTEN_HOST}:${LISTEN_PORT}:`, err);
  }
  process.exit(1);
});

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  console.log(
    `[auth-proxy] listening on ${LISTEN_HOST}:${LISTEN_PORT}, auth_mode=${AUTH_MODE}, upstream=127.0.0.1:${UPSTREAM_PORT}`,
  );
});
