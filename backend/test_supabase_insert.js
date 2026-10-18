const https = require('https');

const supabaseUrl = 'aqypxoaugkktwqlxnorr.supabase.co';
const anonKey = 'sb_publishable_JxIEcyRbkNCTKi51fHgBRQ_nLBYJ6tw';

const payload = JSON.stringify({
  room: 'main',
  author: 'TestUser',
  text: 'Testing insert from backend script'
});

const options = {
  hostname: supabaseUrl,
  port: 443,
  path: '/rest/v1/messages',
  method: 'POST',
  headers: {
    'apikey': anonKey,
    'Authorization': `Bearer ${anonKey}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
    'Content-Length': Buffer.byteLength(payload)
  }
};

console.log('Sending POST to aqypxoaugkktwqlxnorr.supabase.co...');
const req = https.request(options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('Status Code:', res.statusCode);
    console.log('Response:', data);
  });
});

req.on('error', (err) => {
  console.error('Request Error:', err);
});

req.write(payload);
req.end();
