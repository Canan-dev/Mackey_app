const fs = require('fs');
const https = require('https');
const path = require('path');

const supabaseUrl = 'rxjhypjjrkamwnbvvipq.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ4amh5cGpqcmthbXduYnZ2aXBxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0MTA1NDcsImV4cCI6MjEwNTk4NjU0N30.ha9yJZpBoTGohW-BfStESfOyewEW7az5hpuole82_tM';
const apkPath = path.join(__dirname, '../build/app/outputs/flutter-apk/app-release.apk');

const stats = fs.statSync(apkPath);
console.log(`Uploading app-release.apk (${(stats.size / 1024 / 1024).toFixed(1)} MB)...`);

const options = {
  hostname: supabaseUrl,
  port: 443,
  path: '/storage/v1/object/attachments/app-release.apk',
  method: 'POST',
  headers: {
    'apikey': anonKey,
    'Authorization': `Bearer ${anonKey}`,
    'x-upsert': 'true',
    'Content-Type': 'application/vnd.android.package-archive',
    'Content-Length': stats.size
  }
};

const req = https.request(options, (res) => {
  let responseData = '';
  res.on('data', (chunk) => responseData += chunk);
  res.on('end', () => {
    console.log('Status Code:', res.statusCode);
    console.log('Response:', responseData);
    if (res.statusCode === 200) {
      console.log('Direct Download URL: https://rxjhypjjrkamwnbvvipq.supabase.co/storage/v1/object/public/attachments/app-release.apk');
    }
  });
});

req.on('error', (e) => {
  console.error('Upload Error:', e);
});

fs.createReadStream(apkPath).pipe(req);
