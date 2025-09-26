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

// Raw body logging middleware (before express.json)
app.use((req, res, next) => {
  if (req.method === 'POST' && req.path.includes('/cart')) {
    let rawBody = '';
    req.setEncoding('utf8');
    
    req.on('data', (chunk) => {
      rawBody += chunk;
    });
    
    req.on('end', () => {
      logger.info('Raw request body (before parsing):', {
        path: req.path,
        contentType: req.get('Content-Type'),
        rawBody: rawBody,
        rawBodyLength: rawBody.length,
        rawBodyBytes: Buffer.from(rawBody).toString('hex')
      });
    });
  }
  next();
});

app.use(express.json());

// Debug middleware to log parsed request body
app.use((req, res, next) => {
  if (req.method === 'POST' && req.path.includes('/cart')) {
    logger.info('Parsed request body:', {
      path: req.path,
      contentType: req.get('Content-Type'),
      body: req.body,
      bodyType: typeof req.body
    });
  }
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    service: 'api-gateway',
    version: '1.0.0'
  });
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
  target: process.env.ORDER_SERVICE_URL || 'http://localhost:3003',
  changeOrigin: true,
  pathRewrite: {
    '^/api': ''
  },
  logLevel: 'debug',
  onError: (err, req, res) => {
    logger.error('Cart service proxy error:', err);
    res.status(500).json({ error: 'Cart service unavailable' });
  }
}));

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('API Gateway Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use('*', (req, res) => {
  logger.warn('Route not found: ' + req.method + ' ' + req.originalUrl);
  res.status(404).json({ error: 'Route not found' });
});

app.listen(PORT, () => {
  logger.info('API Gateway running on port ' + PORT);
  console.log('API Gateway running on port ' + PORT);
});
