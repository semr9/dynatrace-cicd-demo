const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Pool } = require('pg');
const axios = require('axios');
const winston = require('winston');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3003;

// Logger configuration
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'order-service.log' })
  ]
});

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:password@localhost:5432/ecommerce'
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

// Custom middleware to log raw request data BEFORE express.json()
app.use((req, res, next) => {
  console.log('=== ORDER SERVICE REQUEST DEBUG ===');
  console.log('Method:', req.method);
  console.log('URL:', req.url);
  console.log('Headers:', JSON.stringify(req.headers, null, 2));
  console.log('Content-Type:', req.get('Content-Type'));
  console.log('Content-Length:', req.get('Content-Length'));
  console.log('Body (before parsing):', req.body);
  console.log('req complete:', req);
  console.log('=====================================');
  next();
});

app.use(express.json());

// Custom middleware to log request data AFTER express.json() parsing
app.use((req, res, next) => {
  if (req.method === 'POST' || req.method === 'PUT') {
    console.log('=== ORDER SERVICE AFTER JSON PARSING ===');
    console.log('Method:', req.method);
    console.log('URL:', req.url);
    console.log('Body (after parsing):', JSON.stringify(req.body, null, 2));
    console.log('Body type:', typeof req.body);
    console.log('Body keys:', req.body ? Object.keys(req.body) : 'No body');
    console.log('==========================================');
  }
  next();
});


// Health check (must be before /orders/:id route)
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    service: 'order-service',
    timestamp: new Date().toISOString()
  });
});

// Helper function to get product details
const getProductDetails = async (productId) => {
  try {
    const response = await axios.get(`${process.env.PRODUCT_SERVICE_URL || 'http://localhost:3002'}/products/${productId}`);
    return response.data;
  } catch (error) {
    logger.error('Error fetching product details:', error);
    throw new Error('Product not found');
  }
};

// Cart endpoints
app.get('/cart', async (req, res) => {
  try {
    // For demo purposes, we'll use user_id = 1 as default
    const userId = 1;
    const result = await pool.query(
      `SELECT c.*, p.name, p.price 
       FROM cart c 
       JOIN products p ON c.product_id = p.id 
       WHERE c.user_id = $1`,
      [userId]
    );
    
    res.json(result.rows);
  } catch (error) {
    logger.error('Error fetching cart:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/cart/add', async (req, res) => {
  console.log('First print Product service - Request body:', req.body);

  try {
    // Enhanced debug logging
    console.log('Second print Product service - Request body:', JSON.stringify(req.body));
    console.log('Order Service - Request headers:', JSON.stringify(req.headers));
    console.log('Second print Product service - Content-Type:', req.get('Content-Type'));
    console.log('Second print Product service - Content-Length:', req.get('Content-Length'));
    console.log('Second print Product service - Request method:', req.method);
    console.log('Second print Product service - Request URL:', req.url);
    
    logger.info('Cart add request received:', {
      body: req.body,
      headers: req.headers,
      contentType: req.get('Content-Type')
    });
    
    const { productId, quantity = 1 } = req.body;
    const userId = 1; // Default user for demo
    
    if (!productId) {
      return res.status(400).json({ error: 'Product ID is required' });
    }
    
    // Check if item already exists in cart
    const existingItem = await pool.query(
      'SELECT * FROM cart WHERE user_id = $1 AND product_id = $2',
      [userId, productId]
    );
    
    if (existingItem.rows.length > 0) {
      // Update quantity
      const result = await pool.query(
        'UPDATE cart SET quantity = quantity + $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2 AND product_id = $3 RETURNING *',
        [quantity, userId, productId]
      );
      res.json(result.rows[0]);
    } else {
      // Add new item
      const result = await pool.query(
        'INSERT INTO cart (user_id, product_id, quantity) VALUES ($1, $2, $3) RETURNING *',
        [userId, productId, quantity]
      );
      res.json(result.rows[0]);
    }
    
    logger.info(`Added product ${productId} to cart for user ${userId}`);
  } catch (error) {
    logger.error('Error adding to cart:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/cart/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    const userId = 1; // Default user for demo
    
    const result = await pool.query(
      'DELETE FROM cart WHERE user_id = $1 AND product_id = $2 RETURNING *',
      [userId, productId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Item not found in cart' });
    }
    
    logger.info(`Removed product ${productId} from cart for user ${userId}`);
    res.status(204).send();
  } catch (error) {
    logger.error('Error removing from cart:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Order endpoints
app.get('/orders', async (req, res) => {
  try {
    const userId = 1; // Default user for demo
    const result = await pool.query(
      'SELECT * FROM orders WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );
    
    res.json(result.rows);
  } catch (error) {
    logger.error('Error fetching orders:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Health check for orders (must be before /orders/:id route)
app.get('/orders/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    service: 'order-service',
    endpoint: 'orders',
    timestamp: new Date().toISOString()
  });
});

app.get('/orders/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const userId = 1; // Default user for demo
    
    const orderResult = await pool.query(
      'SELECT * FROM orders WHERE id = $1 AND user_id = $2',
      [id, userId]
    );
    
    if (orderResult.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    
    const itemsResult = await pool.query(
      `SELECT oi.*, p.name, p.price 
       FROM order_items oi 
       JOIN products p ON oi.product_id = p.id 
       WHERE oi.order_id = $1`,
      [id]
    );
    
    res.json({
      ...orderResult.rows[0],
      items: itemsResult.rows
    });
  } catch (error) {
    logger.error('Error fetching order:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/orders', async (req, res) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    const { items, shipping_address } = req.body;
    const userId = 1; // Default user for demo
    
    if (!items || items.length === 0) {
      throw new Error('No items provided');
    }
    
    // Calculate total amount
    let totalAmount = 0;
    const orderItems = [];
    
    for (const item of items) {
      const product = await getProductDetails(item.product_id);
      const itemTotal = product.price * item.quantity;
      totalAmount += itemTotal;
      
      orderItems.push({
        product_id: item.product_id,
        quantity: item.quantity,
        price: product.price
      });
    }
    
    // Create order
    const orderResult = await client.query(
      'INSERT INTO orders (user_id, total_amount, shipping_address, status) VALUES ($1, $2, $3, $4) RETURNING *',
      [userId, totalAmount, shipping_address || 'Default Address', 'pending']
    );
    
    const order = orderResult.rows[0];
    
    // Create order items
    for (const item of orderItems) {
      await client.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4)',
        [order.id, item.product_id, item.quantity, item.price]
      );
    }
    
    // Clear cart
    await client.query('DELETE FROM cart WHERE user_id = $1', [userId]);
    
    // Process payment (simulate)
    try {
      const paymentResponse = await axios.post(
        `${process.env.PAYMENT_SERVICE_URL || 'http://localhost:3004'}/payments`,
        { order_id: order.id, amount: totalAmount }
      );
      
      if (paymentResponse.data.status === 'success') {
        await client.query(
          'UPDATE orders SET status = $1 WHERE id = $2',
          ['processing', order.id]
        );
      }
    } catch (paymentError) {
      logger.error('Payment processing failed:', paymentError);
      // Order remains in pending status
    }
    
    await client.query('COMMIT');
    
    logger.info(`Order created: ${order.id} for user ${userId}`);
    res.status(201).json(order);
    
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error creating order:', error);
    res.status(500).json({ error: error.message || 'Internal server error' });
  } finally {
    client.release();
  }
});

app.put('/orders/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    const validStatuses = ['pending', 'processing', 'shipped', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    
    const result = await pool.query(
      'UPDATE orders SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING *',
      [status, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    
    logger.info(`Order ${id} status updated to ${status}`);
    res.json(result.rows[0]);
  } catch (error) {
    logger.error('Error updating order status:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(PORT, () => {
  logger.info(`Order service running on port ${PORT}`);
  console.log(`Order service running on port ${PORT}`);
});
