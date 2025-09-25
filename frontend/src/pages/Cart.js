import React, { useState, useEffect } from 'react';
import { Container, Card, Button, Row, Col, Alert } from 'react-bootstrap';
import axios from 'axios';

const Cart = () => {
  const [cartItems, setCartItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchCartItems();
  }, []);

  const fetchCartItems = async () => {
    try {
      const response = await axios.get('/api/cart');
      setCartItems(response.data);
    } catch (err) {
      setError('Failed to load cart items');
      console.error('Error fetching cart:', err);
    } finally {
      setLoading(false);
    }
  };

  const removeFromCart = async (productId) => {
    try {
      await axios.delete(`/api/cart/${productId}`);
      fetchCartItems(); // Refresh cart
    } catch (err) {
      alert('Failed to remove item from cart');
      console.error('Error removing from cart:', err);
    }
  };

  const checkout = async () => {
    try {
      await axios.post('/api/orders', { items: cartItems });
      alert('Order placed successfully!');
      setCartItems([]);
    } catch (err) {
      alert('Failed to place order');
      console.error('Error placing order:', err);
    }
  };

  const totalAmount = cartItems.reduce((total, item) => total + (item.price * item.quantity), 0);

  if (loading) {
    return <Container>Loading cart...</Container>;
  }

  if (error) {
    return (
      <Container>
        <Alert variant="danger">{error}</Alert>
      </Container>
    );
  }

  return (
    <Container>
      <h2>Shopping Cart</h2>
      
      {cartItems.length === 0 ? (
        <Alert variant="info">Your cart is empty</Alert>
      ) : (
        <>
          <Row>
            {cartItems.map((item) => (
              <Col md={6} key={item.product_id} className="mb-3">
                <Card>
                  <Card.Body>
                    <Card.Title>{item.name}</Card.Title>
                    <Card.Text>Price: ${item.price}</Card.Text>
                    <Card.Text>Quantity: {item.quantity}</Card.Text>
                    <Card.Text>Subtotal: ${(item.price * item.quantity).toFixed(2)}</Card.Text>
                    <Button 
                      variant="danger" 
                      size="sm" 
                      onClick={() => removeFromCart(item.product_id)}
                    >
                      Remove
                    </Button>
                  </Card.Body>
                </Card>
              </Col>
            ))}
          </Row>
          
          <Card className="mt-4">
            <Card.Body>
              <h4>Total: ${totalAmount.toFixed(2)}</h4>
              <Button variant="success" size="lg" onClick={checkout}>
                Checkout
              </Button>
            </Card.Body>
          </Card>
        </>
      )}
    </Container>
  );
};

export default Cart;
