const crypto = require('crypto');

// Generate 32-byte secret for destination token HMAC
const secret = crypto.randomBytes(32).toString('base64');

// Generate X25519 server keypair
const { privateKey: x25519Private } = crypto.generateKeyPairSync('x25519');
const x25519PrivateBase64 = x25519Private.export({ type: 'pkcs8', format: 'der' }).toString('base64');

// Generate Ed25519 server keypair
const { privateKey: ed25519Private } = crypto.generateKeyPairSync('ed25519');
const ed25519PrivateBase64 = ed25519Private.export({ type: 'pkcs8', format: 'der' }).toString('base64');

console.log('--- GENERATED OFFLINE MESH SERVER KEYS ---');
console.log('Copy these keys to your backend environment variable files (.env):\n');
console.log(`OFFLINE_MESH_ENABLED=true`);
console.log(`MESH_SERVER_SECRET="${secret}"`);
console.log(`MESH_SERVER_X25519_PRIVATE="${x25519PrivateBase64}"`);
console.log(`MESH_SERVER_ED25519_PRIVATE="${ed25519PrivateBase64}"`);
console.log('\n------------------------------------------');
