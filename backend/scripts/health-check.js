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
  timeout: 10000
};

console.log(`🔍 Checking health at ${options.hostname}:${options.port}${options.path}`);

const req = http.request(options, (res) => {
  console.log(`📊 Health check status: ${res.statusCode}`);
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    try {
      const response = JSON.parse(data);
      console.log('📋 Health response:', response);
      
      if (res.statusCode === 200 && response.ok) {
        console.log('✅ Application is healthy');
        process.exit(0);
      } else {
        console.log('❌ Application health check failed');
        process.exit(1);
      }
    } catch (error) {
      console.log('❌ Invalid health response:', data);
      process.exit(1);
    }
  });
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
