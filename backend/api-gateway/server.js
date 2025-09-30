const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { createProxyMiddleware } = require('http-proxy-middleware');
const winston = require('winston');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 4000;

// Logger configuration
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'api-gateway.log' })
  ]
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));



app.use(express.json());

// Health check endpoint 
app.get('/health', (req, res) => {
  try {
    res.status(200).json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      service: 'api-gateway',
      version: '1.0.0'
    });
  } catch (error) {
    console.error('API Gateway - Health check error:', error);
    logger.error('Health check error:', error);
    
    if (!res.headersSent) {
      res.status(500).json({ 
        status: 'unhealthy', 
        error: error.message,
        timestamp: new Date().toISOString(),
        service: 'api-gateway'
      });
    }
  }
});

// API Routes with proxy middleware
app.use('/api/users', createProxyMiddleware({
  target: process.env.USER_SERVICE_URL || 'http://localhost:3001',
  changeOrigin: true,
  pathRewrite: {
    '^/api': ''
  },
  logLevel: 'debug',
  onError: (err, req, res) => {
    logger.error('User service proxy error:', err);
    res.status(500).json({ error: 'User service unavailable' });
  }
}));

app.use('/api/products', createProxyMiddleware({
  target: process.env.PRODUCT_SERVICE_URL || 'http://localhost:3002',
  changeOrigin: true,
  pathRewrite: {
    '^/api': ''
  },
  logLevel: 'debug',
  onError: (err, req, res) => {
    logger.error('Product service proxy error:', err);
    res.status(500).json({ error: 'Product service unavailable' });
  }
}));

app.use('/api/orders', createProxyMiddleware({
  target: process.env.ORDER_SERVICE_URL || 'http://localhost:3003',
  changeOrigin: true,
  pathRewrite: {
    '^/api': ''
  },
  logLevel: 'debug',
  onError: (err, req, res) => {
    logger.error('Order service proxy error:', err);
    res.status(500).json({ error: 'Order service unavailable' });
  }
}));

app.use('/api/payments', createProxyMiddleware({
  target: process.env.PAYMENT_SERVICE_URL || 'http://localhost:3004',
  changeOrigin: true,
  pathRewrite: {
    '^/api': ''
  },
  logLevel: 'debug',
  onError: (err, req, res) => {
    logger.error('Payment service proxy error:', err);
    res.status(500).json({ error: 'Payment service unavailable' });
  }
}));

// Cart endpoints (handled by order service)
app.use('/api/cart', createProxyMiddleware({
  target: process.env.ORDER_SERVICE_URL || 'http://order-service:3003',
  changeOrigin: true,
  pathRewrite: {
    '^/api': ''
  },
  logLevel: 'debug',
  timeout: 30000, // 30 seconds timeout
  proxyTimeout: 30000, // 30 seconds proxy timeout
  onProxyReq: (proxyReq, req, res) => {
    try {
      console.log('API Gateway - Request body before proxy:', JSON.stringify(req.body));
      console.log('API Gateway - Request body before proxy - normal :', req.body);
      console.log('API Gateway - Request headers:', JSON.stringify(req.headers));
      console.log('API Gateway - Request method:', req.method);
      console.log('API Gateway - Request URL:', req.url);
      
      // Log proxy request details
      console.log('API Gateway - Proxy request target:', proxyReq.path);
      console.log('API Gateway - Proxy request headers:', proxyReq.getHeaders());
      
    } catch (error) {
      console.error('API Gateway - Error in onProxyReq:', error);
      logger.error('Error in onProxyReq callback:', error);
    }
  },
  onError: (err, req, res) => {
    try {
      console.error('API Gateway - Cart service proxy error:', err);
      logger.error('Cart service proxy error:', err);
      
      // Send appropriate error response
      if (!res.headersSent) {
        res.status(500).json({ 
          error: 'Cart service unavailable',
          message: err.message,
          timestamp: new Date().toISOString()
        });
      }
    } catch (responseError) {
      console.error('API Gateway - Error sending error response:', responseError);
      logger.error('Error sending error response:', responseError);
    }
  },
  onProxyRes: (proxyRes, req, res) => {
    try {
      console.log('API Gateway - Proxy response status:', proxyRes.statusCode);
      console.log('API Gateway - Proxy response headers:', proxyRes.headers);
    } catch (error) {
      console.error('API Gateway - Error in onProxyRes:', error);
      logger.error('Error in onProxyRes callback:', error);
    }
  }
}));

// 404 handler
app.use('*', (req, res) => {
  logger.warn('Route not found: ' + req.method + ' ' + req.originalUrl);
  res.status(404).json({ error: 'Route not found' });
});

try {
  app.listen(PORT, () => {
    logger.info('API Gateway running on port ' + PORT);
    console.log('API Gateway running on port ' + PORT);
  });
} catch (error) {
  console.error('API Gateway - Failed to start server:', error);
  logger.error('Failed to start server:', error);
  process.exit(1);
}


// Error handling middleware
app.use((err, req, res, next) => {
  try {
    console.error('API Gateway - Unhandled error:', err);
    logger.error('API Gateway Error:', err);
    
    // Don't send response if headers already sent
    if (!res.headersSent) {
      res.status(500).json({ 
        error: 'Internal server error',
        message: err.message,
        timestamp: new Date().toISOString(),
        service: 'api-gateway'
      });
    }
  } catch (responseError) {
    console.error('API Gateway - Error in error handler:', responseError);
    logger.error('Error in error handler:', responseError);
  }
});
