const jwt = require('jsonwebtoken');
const http = require('http');

const secret = 'swasthyatap_secret_key_2025_secure';
const token = jwt.sign(
  { citizenId: 'x7k9m2', phoneNumber: '9876543210' },
  secret,
  { expiresIn: '1h' }
);

console.log('Generated Token:', token);

const options = {
  hostname: 'localhost',
  port: 3011,
  path: '/api/citizens/x7k9m2/nfc-token',
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
};

const req = http.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  res.on('end', () => {
    console.log('Response Status:', res.statusCode);
    console.log('Response Body:', data);
  });
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

req.end();
