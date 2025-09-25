const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Pool } = require('pg');
const winston = require('winston');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3004;

// Logger configuration
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'payment-service.log' })
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

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    service: 'payment-service',
    timestamp: new Date().toISOString()
  });
});

// Simulate payment processing
const processPayment = async (orderId, amount, paymentMethod = 'credit_card') => {
  // Simulate payment processing time
  await new Promise(resolve => setTimeout(resolve, 1000 + Math.random() * 2000));
  
  // Simulate payment success/failure (90% success rate)
  const isSuccess = Math.random() > 0.1;
  
  return {
    transaction_id: `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
    status: isSuccess ? 'success' : 'failed',
    amount,
    payment_method: paymentMethod,
    processed_at: new Date().toISOString()
  };
};

// Payment endpoints
app.post('/payments', async (req, res) => {
  try {
    const { order_id, amount, payment_method = 'credit_card' } = req.body;
    
    if (!order_id || !amount) {
      return res.status(400).json({ error: 'Order ID and amount are required' });
    }
    
    // Validate amount
    if (amount <= 0) {
      return res.status(400).json({ error: 'Amount must be greater than 0' });
    }
    
    // Process payment
    const paymentResult = await processPayment(order_id, amount, payment_method);
    
    // Store payment record
    const result = await pool.query(
      `INSERT INTO payments (order_id, transaction_id, amount, payment_method, status, processed_at) 
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [order_id, paymentResult.transaction_id, amount, payment_method, paymentResult.status, paymentResult.processed_at]
    );
    
    logger.info(`Payment processed for order ${order_id}: ${paymentResult.status}`);
    
    res.status(201).json({
      payment_id: result.rows[0].id,
      transaction_id: paymentResult.transaction_id,
      status: paymentResult.status,
      amount,
      payment_method,
      processed_at: paymentResult.processed_at
    });
    
  } catch (error) {
    logger.error('Error processing payment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/payments/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;
    
    const result = await pool.query(
      'SELECT * FROM payments WHERE order_id = $1 ORDER BY created_at DESC',
      [orderId]
    );
    
    res.json(result.rows);
  } catch (error) {
    logger.error('Error fetching payments:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/payments/transaction/:transactionId', async (req, res) => {
  try {
    const { transactionId } = req.params;
    
    const result = await pool.query(
      'SELECT * FROM payments WHERE transaction_id = $1',
      [transactionId]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Payment not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    logger.error('Error fetching payment:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Refund endpoint
app.post('/payments/:transactionId/refund', async (req, res) => {
  try {
    const { transactionId } = req.params;
    const { amount } = req.body;
    
    // Get original payment
    const paymentResult = await pool.query(
      'SELECT * FROM payments WHERE transaction_id = $1',
      [transactionId]
    );
    
    if (paymentResult.rows.length === 0) {
      return res.status(404).json({ error: 'Payment not found' });
    }
    
    const payment = paymentResult.rows[0];
    
    if (payment.status !== 'success') {
      return res.status(400).json({ error: 'Can only refund successful payments' });
    }
    
    // Simulate refund processing
    const refundResult = await processPayment(payment.order_id, amount || payment.amount, 'refund');
    
    // Create refund record
    const result = await pool.query(
      `INSERT INTO payments (order_id, transaction_id, amount, payment_method, status, processed_at, refund_of) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [payment.order_id, `refund_${refundResult.transaction_id}`, amount || payment.amount, 'refund', refundResult.status, refundResult.processed_at, payment.id]
    );
    
    logger.info(`Refund processed for transaction ${transactionId}: ${refundResult.status}`);
    
    res.status(201).json({
      refund_id: result.rows[0].id,
      transaction_id: `refund_${refundResult.transaction_id}`,
      status: refundResult.status,
      amount: amount || payment.amount,
      refund_of: payment.id
    });
    
  } catch (error) {
    logger.error('Error processing refund:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Payment statistics endpoint
app.get('/payments/stats', async (req, res) => {
  try {
    const { start_date, end_date } = req.query;
    
    let query = `
      SELECT 
        COUNT(*) as total_payments,
        COUNT(CASE WHEN status = 'success' THEN 1 END) as successful_payments,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_payments,
        SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END) as total_amount,
        AVG(CASE WHEN status = 'success' THEN amount ELSE NULL END) as average_amount
      FROM payments
    `;
    
    const params = [];
    let paramCount = 0;
    
    if (start_date) {
      paramCount++;
      query += ` WHERE created_at >= $${paramCount}`;
      params.push(start_date);
    }
    
    if (end_date) {
      paramCount++;
      query += paramCount === 1 ? ' WHERE' : ' AND';
      query += ` created_at <= $${paramCount}`;
      params.push(end_date);
    }
    
    const result = await pool.query(query, params);
    
    res.json(result.rows[0]);
  } catch (error) {
    logger.error('Error fetching payment stats:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(PORT, () => {
  logger.info(`Payment service running on port ${PORT}`);
  console.log(`Payment service running on port ${PORT}`);
});
