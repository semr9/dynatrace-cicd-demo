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

app.use(express.json());

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
  try {
    
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
    logger.info('🚀 Starting order creation process', { userId: 1 });
    
    // Begin transaction
    try {
      await client.query('BEGIN');
      logger.info('✅ Database transaction started');
    } catch (txError) {
      logger.error('❌ Failed to start transaction:', txError);
      throw new Error('Failed to start database transaction');
    }
    
    const { items, shipping_address } = req.body;
    const userId = 1; // Default user for demo
    
    logger.info('📋 Order request received', { 
      itemsCount: items?.length || 0, 
      shippingAddress: shipping_address || 'Default Address' 
    });
    
    if (!items || items.length === 0) {
      logger.warn('⚠️ No items provided in order request');
      throw new Error('No items provided');
    }
    
    // Calculate total amount
    let totalAmount = 0;
    const orderItems = [];
    
    logger.info(`🔍 Processing ${items.length} items for order calculation`);
    
    for (const item of items) {
      try {
        logger.info(`📦 Fetching product details for ID: ${item.product_id}`);
        const product = await getProductDetails(item.product_id);
        const itemTotal = product.price * item.quantity;
        totalAmount += itemTotal;
        
        orderItems.push({
          product_id: item.product_id,
          quantity: item.quantity,
          price: product.price
        });
        
        logger.info(`💰 Item processed: Product ${item.product_id} - ${item.quantity} x $${product.price} = $${itemTotal}`);
      } catch (productError) {
        logger.error(`❌ Failed to process item ${item.product_id}:`, productError);
        throw new Error(`Failed to process product ${item.product_id}: ${productError.message}`);
      }
    }
    
    logger.info(`💵 Total order amount calculated: $${totalAmount}`);
    
    // Create order
    let order;
    try {
      logger.info('📋 Creating order record in database');
      const orderResult = await client.query(
        'INSERT INTO orders (user_id, total_amount, shipping_address, status) VALUES ($1, $2, $3, $4) RETURNING *',
        [userId, totalAmount, shipping_address || 'Default Address', 'pending']
      );
      
      order = orderResult.rows[0];
      logger.info(`✅ Order created successfully with ID: ${order.id}`, {
        orderId: order.id,
        userId: order.user_id,
        totalAmount: order.total_amount,
        status: order.status
      });
    } catch (orderError) {
      logger.error('❌ Failed to create order record:', orderError);
      throw new Error(`Failed to create order: ${orderError.message}`);
    }
    
    // Create order items
    logger.info(`📦 Creating ${orderItems.length} order items`);
    for (let i = 0; i < orderItems.length; i++) {
      const item = orderItems[i];
      try {
        logger.info(`  - Creating order item ${i + 1}/${orderItems.length}: Product ${item.product_id}`);
        const result = await client.query(
          'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4) RETURNING *',
          [order.id, item.product_id, item.quantity, item.price]
        );
        
        logger.info(`  ✅ Order item created with ID: ${result.rows[0]?.id}`, {
          itemId: result.rows[0]?.id,
          orderId: order.id,
          productId: item.product_id,
          quantity: item.quantity,
          price: item.price
        });
      } catch (itemError) {
        logger.error(`  ❌ Failed to create order item for product ${item.product_id}:`, itemError);
        throw new Error(`Failed to create order item for product ${item.product_id}: ${itemError.message}`);
      }
    }
    
    // Clear cart
    try {
      logger.info(`🗑️ Clearing cart for user ${userId}`);
      const deleteResult = await client.query('DELETE FROM cart WHERE user_id = $1', [userId]);
      logger.info(`✅ Cart cleared successfully: ${deleteResult.rowCount} items removed`, {
        userId: userId,
        itemsRemoved: deleteResult.rowCount
      });
    } catch (cartError) {
      logger.error('❌ Failed to clear cart:', cartError);
      throw new Error(`Failed to clear cart: ${cartError.message}`);
    }
    
    // Process payment (simulate)
    try {
      logger.info(`💳 Processing payment for order ${order.id}`, { amount: totalAmount });
      const paymentResponse = await axios.post(
        `${process.env.PAYMENT_SERVICE_URL || 'http://localhost:3004'}/payments`,
        { order_id: order.id, amount: totalAmount }
      );
      
      logger.info(`💳 Payment response received:`, { 
        status: paymentResponse.data.status,
        orderId: order.id 
      });
      
      if (paymentResponse.data.status === 'success') {
        try {
          await client.query(
            'UPDATE orders SET status = $1 WHERE id = $2',
            ['processing', order.id]
          );
          logger.info(`✅ Order status updated to 'processing' for order ${order.id}`);
        } catch (statusError) {
          logger.error(`❌ Failed to update order status:`, statusError);
          throw new Error(`Failed to update order status: ${statusError.message}`);
        }
      }
    } catch (paymentError) {
      logger.error('⚠️ Payment processing failed (order remains in pending status):', paymentError);
      // Order remains in pending status - this is acceptable
    }
    
    // Commit transaction
    try {
      await client.query('COMMIT');
      logger.info('✅ Database transaction committed successfully');
    } catch (commitError) {
      logger.error('❌ Failed to commit transaction:', commitError);
      throw new Error('Failed to commit database transaction');
    }
    
    logger.info(`🎉 Order ${order.id} completed successfully!`, {
      orderId: order.id,
      userId: userId,
      totalAmount: totalAmount,
      itemsCount: orderItems.length,
      finalStatus: 'processing'
    });
    
    res.status(201).json(order);
    
  } catch (error) {
    // Rollback transaction
    try {
      await client.query('ROLLBACK');
      logger.info('🔄 Database transaction rolled back');
    } catch (rollbackError) {
      logger.error('❌ Failed to rollback transaction:', rollbackError);
    }
    
    logger.error('❌ Order creation failed:', {
      error: error.message,
      stack: error.stack,
      userId: 1
    });
    
    res.status(500).json({ error: error.message || 'Internal server error' });
  } finally {
    try {
      client.release();
      logger.info('🔌 Database connection released');
    } catch (releaseError) {
      logger.error('❌ Failed to release database connection:', releaseError);
    }
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
