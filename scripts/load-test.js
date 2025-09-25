// Load testing script for Dynatrace CI/CD automation testing
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

// Configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';
const VUS = __ENV.VUS || 10; // Virtual Users
const DURATION = __ENV.DURATION || '30s';

export const options = {
  stages: [
    { duration: '10s', target: 5 },   // Ramp up to 5 users
    { duration: '30s', target: 10 },  // Stay at 10 users
    { duration: '10s', target: 20 },  // Ramp up to 20 users
    { duration: '30s', target: 20 },  // Stay at 20 users
    { duration: '10s', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // 95% of requests must complete below 1s
    http_req_failed: ['rate<0.1'],     // Error rate must be below 10%
    errors: ['rate<0.1'],              // Custom error rate must be below 10%
  },
};

// Test data
const testUsers = [
  { username: 'loadtest1', email: 'loadtest1@example.com', password: 'password123' },
  { username: 'loadtest2', email: 'loadtest2@example.com', password: 'password123' },
  { username: 'loadtest3', email: 'loadtest3@example.com', password: 'password123' },
  { username: 'loadtest4', email: 'loadtest4@example.com', password: 'password123' },
  { username: 'loadtest5', email: 'loadtest5@example.com', password: 'password123' },
];

export function setup() {
  console.log(`Starting load test against: ${BASE_URL}`);
  
  // Pre-register test users
  testUsers.forEach(user => {
    const response = http.post(`${BASE_URL}/api/users/register`, JSON.stringify(user), {
      headers: { 'Content-Type': 'application/json' },
    });
    console.log(`Registered user: ${user.username} - Status: ${response.status}`);
  });
  
  return { baseUrl: BASE_URL };
}

export default function(data) {
  const user = testUsers[Math.floor(Math.random() * testUsers.length)];
  
  // Test 1: Health Check
  const healthResponse = http.get(`${data.baseUrl}/health`);
  check(healthResponse, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 500ms': (r) => r.timings.duration < 500,
  }) || errorRate.add(1);
  
  responseTime.add(healthResponse.timings.duration);
  sleep(0.5);
  
  // Test 2: Get Products
  const productsResponse = http.get(`${data.baseUrl}/api/products`);
  check(productsResponse, {
    'products endpoint status is 200': (r) => r.status === 200,
    'products endpoint returns data': (r) => JSON.parse(r.body).length > 0,
    'products response time < 1000ms': (r) => r.timings.duration < 1000,
  }) || errorRate.add(1);
  
  responseTime.add(productsResponse.timings.duration);
  sleep(0.3);
  
  // Test 3: User Login
  const loginResponse = http.post(`${data.baseUrl}/api/users/login`, JSON.stringify({
    email: user.email,
    password: user.password
  }), {
    headers: { 'Content-Type': 'application/json' },
  });
  
  let token = null;
  if (check(loginResponse, {
    'login status is 200': (r) => r.status === 200,
    'login returns token': (r) => JSON.parse(r.body).token !== undefined,
  })) {
    token = JSON.parse(loginResponse.body).token;
  } else {
    errorRate.add(1);
  }
  
  responseTime.add(loginResponse.timings.duration);
  sleep(0.2);
  
  // Test 4: Add to Cart (if login successful)
  if (token) {
    const products = JSON.parse(productsResponse.body);
    if (products.length > 0) {
      const productId = products[Math.floor(Math.random() * products.length)].id;
      
      const cartResponse = http.post(`${data.baseUrl}/api/cart/add`, JSON.stringify({
        productId: productId,
        quantity: Math.floor(Math.random() * 3) + 1
      }), {
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
      });
      
      check(cartResponse, {
        'add to cart status is 200': (r) => r.status === 200,
        'add to cart response time < 1000ms': (r) => r.timings.duration < 1000,
      }) || errorRate.add(1);
      
      responseTime.add(cartResponse.timings.duration);
    }
  }
  
  sleep(0.5);
  
  // Test 5: Get Cart
  if (token) {
    const getCartResponse = http.get(`${data.baseUrl}/api/cart`, {
      headers: { 'Authorization': `Bearer ${token}` },
    });
    
    check(getCartResponse, {
      'get cart status is 200': (r) => r.status === 200,
      'get cart response time < 1000ms': (r) => r.timings.duration < 1000,
    }) || errorRate.add(1);
    
    responseTime.add(getCartResponse.timings.duration);
  }
  
  sleep(0.3);
  
  // Test 6: Create Order (occasionally)
  if (token && Math.random() < 0.3) { // 30% chance
    const cartResponse = http.get(`${data.baseUrl}/api/cart`, {
      headers: { 'Authorization': `Bearer ${token}` },
    });
    
    if (cartResponse.status === 200) {
      const cartItems = JSON.parse(cartResponse.body);
      if (cartItems.length > 0) {
        const orderResponse = http.post(`${data.baseUrl}/api/orders`, JSON.stringify({
          items: cartItems,
          shipping_address: 'Load Test Address, Test City, Test Country'
        }), {
          headers: { 
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
        });
        
        check(orderResponse, {
          'create order status is 201': (r) => r.status === 201,
          'create order response time < 2000ms': (r) => r.timings.duration < 2000,
        }) || errorRate.add(1);
        
        responseTime.add(orderResponse.timings.duration);
      }
    }
  }
  
  sleep(1);
}

export function teardown(data) {
  console.log('Load test completed');
  console.log(`Final error rate: ${errorRate.values.rate}`);
  console.log(`Average response time: ${responseTime.values.avg}ms`);
}
