#!/usr/bin/env node

/**
 * Railway Health Check Script
 * This script can be used to verify the application is working correctly
 */

const http = require('http');

const options = {
  hostname: process.env.HOST || 'localhost',
  port: process.env.PORT || 8080,
  path: '/health',
  method: 'GET',
  timeout: 5000
};

const req = http.request(options, (res) => {
  console.log(`Health check status: ${res.statusCode}`);
  
  if (res.statusCode === 200) {
    console.log('✅ Application is healthy');
    process.exit(0);
  } else {
    console.log('❌ Application health check failed');
    process.exit(1);
  }
});

req.on('error', (err) => {
  console.error('❌ Health check failed:', err.message);
  process.exit(1);
});

req.on('timeout', () => {
  console.error('❌ Health check timed out');
  req.destroy();
  process.exit(1);
});

req.end();
