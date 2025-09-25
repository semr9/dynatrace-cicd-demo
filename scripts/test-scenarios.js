// Test scenarios for Dynatrace CI/CD automation testing
const axios = require('axios');
const fs = require('fs');
const path = require('path');

// Configuration
const BASE_URL = process.env.BASE_URL || 'http://localhost:4000';
const TEST_USER = {
  username: 'testuser',
  email: 'test@example.com',
  password: 'testpassword123'
};

// Test results tracking
const testResults = {
  passed: 0,
  failed: 0,
  total: 0,
  details: []
};

// Helper function to log test results
const logTestResult = (testName, passed, details = '') => {
  testResults.total++;
  if (passed) {
    testResults.passed++;
    console.log(`✅ ${testName}: PASSED`);
  } else {
    testResults.failed++;
    console.log(`❌ ${testName}: FAILED - ${details}`);
  }
  testResults.details.push({ testName, passed, details });
};

// Helper function to wait
const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Test scenarios
const testScenarios = {
  // Test 1: Normal application flow
  async testNormalFlow() {
    console.log('Testing normal application flow...');
    try {
      // Health check
      const healthResponse = await axios.get(`${BASE_URL}/health`);
      logTestResult('Health Check', healthResponse.status === 200);
      
      // Get products
      const productsResponse = await axios.get(`${BASE_URL}/api/products`);
      logTestResult('Products Endpoint', productsResponse.status === 200 && productsResponse.data.length > 0);
      
      // User registration
      const registerResponse = await axios.post(`${BASE_URL}/api/users/register`, TEST_USER);
      logTestResult('User Registration', registerResponse.status === 201);
      
      return true;
    } catch (error) {
      logTestResult('Normal Flow Test', false, error.message);
      return false;
    }
  },

  // Test 2: Configuration drift simulation
  async testConfigurationDrift() {
    console.log('Testing configuration drift scenario...');
    try {
      // Simulate configuration drift by changing environment variables
      process.env.DATABASE_URL = 'postgresql://wrong:password@wrong-host:5432/wrong-db';
      
      // Wait a moment for the change to take effect
      await wait(1000);
      
      const healthResponse = await axios.get(`${BASE_URL}/health`);
      
      // If health check still passes, that's unexpected (configuration drift not detected)
      if (healthResponse.status === 200) {
        logTestResult('Configuration Drift Detection', false, 'Health check passed despite wrong config');
        return false;
      } else {
        logTestResult('Configuration Drift Detection', true, 'Health check failed as expected');
        return true;
      }
    } catch (error) {
      logTestResult('Configuration Drift Detection', true, 'Error detected as expected');
      return true;
    }
  },

  // Test 3: High load scenario
  async testHighLoad() {
    console.log('Testing high load scenario...');
    try {
      const promises = [];
      const requestCount = 100;
      
      // Create multiple concurrent requests
      for (let i = 0; i < requestCount; i++) {
        promises.push(axios.get(`${BASE_URL}/api/products`));
      }
      
      const startTime = Date.now();
      const responses = await Promise.allSettled(promises);
      const endTime = Date.now();
      const duration = endTime - startTime;
      
      const successfulRequests = responses.filter(r => r.status === 'fulfilled').length;
      const successRate = (successfulRequests / requestCount) * 100;
      
      logTestResult('High Load Test', successRate >= 90, 
        `${successfulRequests}/${requestCount} requests successful (${successRate.toFixed(1)}%) in ${duration}ms`);
      
      return successRate >= 90;
    } catch (error) {
      logTestResult('High Load Test', false, error.message);
      return false;
    }
  },

  // Test 4: Database connectivity issues
  async testDatabaseIssues() {
    console.log('Testing database connectivity issues...');
    try {
      // Try to register a user (this will hit the database)
      const response = await axios.post(`${BASE_URL}/api/users/register`, {
        username: 'db_test_user',
        email: 'dbtest@example.com',
        password: 'password123'
      });
      
      logTestResult('Database Connectivity', response.status === 201 || response.status === 409, 
        'Database operations working');
      return true;
    } catch (error) {
      if (error.response?.status === 500) {
        logTestResult('Database Connectivity', false, 'Database error detected');
        return false;
      } else {
        logTestResult('Database Connectivity', true, 'Expected error handling');
        return true;
      }
    }
  },

  // Test 5: Service failure simulation
  async testServiceFailure() {
    console.log('Testing service failure scenario...');
    try {
      // Try to access a non-existent endpoint
      await axios.get(`${BASE_URL}/api/nonexistent-service`);
      logTestResult('Service Failure Handling', false, 'Non-existent service should return 404');
      return false;
    } catch (error) {
      if (error.response?.status === 404) {
        logTestResult('Service Failure Handling', true, '404 returned as expected');
        return true;
      } else {
        logTestResult('Service Failure Handling', false, `Unexpected error: ${error.message}`);
        return false;
      }
    }
  },

  // Test 6: Performance monitoring
  async testPerformanceMonitoring() {
    console.log('Testing performance monitoring...');
    try {
      const startTime = Date.now();
      const response = await axios.get(`${BASE_URL}/api/products`);
      const endTime = Date.now();
      const responseTime = endTime - startTime;
      
      const isAcceptable = responseTime < 1000; // Less than 1 second
      logTestResult('Performance Monitoring', isAcceptable, 
        `Response time: ${responseTime}ms`);
      
      return isAcceptable;
    } catch (error) {
      logTestResult('Performance Monitoring', false, error.message);
      return false;
    }
  },

  // Test 7: Error logging and monitoring
  async testErrorLogging() {
    console.log('Testing error logging and monitoring...');
    try {
      // Try to create a product with invalid data
      await axios.post(`${BASE_URL}/api/products`, {
        // Missing required fields
        description: 'Test product without name or price'
      });
      
      logTestResult('Error Logging', false, 'Should have failed validation');
      return false;
    } catch (error) {
      if (error.response?.status === 400) {
        logTestResult('Error Logging', true, 'Validation error handled correctly');
        return true;
      } else {
        logTestResult('Error Logging', false, `Unexpected error: ${error.message}`);
        return false;
      }
    }
  },

  // Test 8: Cart functionality
  async testCartFunctionality() {
    console.log('Testing cart functionality...');
    try {
      // Get products first
      const productsResponse = await axios.get(`${BASE_URL}/api/products`);
      if (productsResponse.data.length === 0) {
        logTestResult('Cart Functionality', false, 'No products available for testing');
        return false;
      }
      
      const productId = productsResponse.data[0].id;
      
      // Add item to cart
      const addToCartResponse = await axios.post(`${BASE_URL}/api/cart/add`, {
        productId: productId,
        quantity: 1
      });
      
      logTestResult('Add to Cart', addToCartResponse.status === 200);
      
      // Get cart contents
      const cartResponse = await axios.get(`${BASE_URL}/api/cart`);
      logTestResult('Get Cart Contents', cartResponse.status === 200);
      
      return true;
    } catch (error) {
      logTestResult('Cart Functionality', false, error.message);
      return false;
    }
  },

  // Test 9: Order processing
  async testOrderProcessing() {
    console.log('Testing order processing...');
    try {
      // First add items to cart
      const productsResponse = await axios.get(`${BASE_URL}/api/products`);
      if (productsResponse.data.length === 0) {
        logTestResult('Order Processing', false, 'No products available for testing');
        return false;
      }
      
      const productId = productsResponse.data[0].id;
      await axios.post(`${BASE_URL}/api/cart/add`, { productId, quantity: 1 });
      
      // Get cart and create order
      const cartResponse = await axios.get(`${BASE_URL}/api/cart`);
      const orderResponse = await axios.post(`${BASE_URL}/api/orders`, {
        items: cartResponse.data,
        shipping_address: 'Test Address, Test City, Test Country'
      });
      
      logTestResult('Order Creation', orderResponse.status === 201);
      
      return true;
    } catch (error) {
      logTestResult('Order Processing', false, error.message);
      return false;
    }
  },

  // Test 10: Payment processing
  async testPaymentProcessing() {
    console.log('Testing payment processing...');
    try {
      // Create a test order first
      const productsResponse = await axios.get(`${BASE_URL}/api/products`);
      if (productsResponse.data.length === 0) {
        logTestResult('Payment Processing', false, 'No products available for testing');
        return false;
      }
      
      const productId = productsResponse.data[0].id;
      await axios.post(`${BASE_URL}/api/cart/add`, { productId, quantity: 1 });
      
      const cartResponse = await axios.get(`${BASE_URL}/api/cart`);
      const orderResponse = await axios.post(`${BASE_URL}/api/orders`, {
        items: cartResponse.data,
        shipping_address: 'Test Address'
      });
      
      // Test payment processing
      const paymentResponse = await axios.post(`${BASE_URL}/api/payments`, {
        order_id: orderResponse.data.id,
        amount: orderResponse.data.total_amount,
        payment_method: 'credit_card'
      });
      
      logTestResult('Payment Processing', paymentResponse.status === 201);
      
      return true;
    } catch (error) {
      logTestResult('Payment Processing', false, error.message);
      return false;
    }
  }
};

// Main test runner
async function runAllTests() {
  console.log('🚀 Starting Dynatrace CI/CD automation test scenarios...\n');
  console.log(`Testing against: ${BASE_URL}\n`);
  
  const startTime = Date.now();
  
  // Run all test scenarios
  for (const [testName, testFunction] of Object.entries(testScenarios)) {
    try {
      await testFunction();
      console.log(''); // Empty line for readability
    } catch (error) {
      logTestResult(testName, false, `Test execution error: ${error.message}`);
      console.log('');
    }
  }
  
  const endTime = Date.now();
  const totalDuration = endTime - startTime;
  
  // Generate test report
  console.log('📊 Test Results Summary:');
  console.log('========================');
  console.log(`Total Tests: ${testResults.total}`);
  console.log(`Passed: ${testResults.passed} ✅`);
  console.log(`Failed: ${testResults.failed} ❌`);
  console.log(`Success Rate: ${((testResults.passed / testResults.total) * 100).toFixed(1)}%`);
  console.log(`Total Duration: ${totalDuration}ms`);
  console.log('');
  
  // Detailed results
  console.log('Detailed Results:');
  console.log('=================');
  testResults.details.forEach(result => {
    const status = result.passed ? '✅' : '❌';
    console.log(`${status} ${result.testName}`);
    if (result.details) {
      console.log(`   ${result.details}`);
    }
  });
  
  // Save results to file
  const reportPath = path.join(__dirname, 'test-results.json');
  fs.writeFileSync(reportPath, JSON.stringify({
    timestamp: new Date().toISOString(),
    baseUrl: BASE_URL,
    summary: {
      total: testResults.total,
      passed: testResults.passed,
      failed: testResults.failed,
      successRate: (testResults.passed / testResults.total) * 100,
      duration: totalDuration
    },
    details: testResults.details
  }, null, 2));
  
  console.log(`\n📄 Detailed report saved to: ${reportPath}`);
  
  // Exit with appropriate code
  process.exit(testResults.failed > 0 ? 1 : 0);
}

// Handle command line execution
if (require.main === module) {
  runAllTests().catch(error => {
    console.error('❌ Test runner failed:', error);
    process.exit(1);
  });
}

module.exports = { testScenarios, runAllTests };
