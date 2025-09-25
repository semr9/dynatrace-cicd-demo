import React from 'react';
import { Container, Row, Col, Button } from 'react-bootstrap';
import { useNavigate } from 'react-router-dom';

const Home = () => {
  const navigate = useNavigate();

  return (
    <div>
      <div className="hero-section">
        <Container>
          <h1>Welcome to E-Commerce Demo</h1>
          <p>Built for Dynatrace CI/CD Automation Testing</p>
          <Button 
            variant="light" 
            size="lg" 
            onClick={() => navigate('/products')}
          >
            Explore Products
          </Button>
        </Container>
      </div>
      
      <Container>
        <Row className="mt-5">
          <Col md={4}>
            <div className="text-center">
              <h3>🚀 Microservices</h3>
              <p>Built with Node.js microservices architecture including API Gateway, User Service, Product Service, Order Service, and Payment Service.</p>
            </div>
          </Col>
          <Col md={4}>
            <div className="text-center">
              <h3>⚡ CI/CD Automation</h3>
              <p>Demonstrates Dynatrace's CI/CD automation capabilities across Build, Deploy, Test, and Validation stages.</p>
            </div>
          </Col>
          <Col md={4}>
            <div className="text-center">
              <h3>📊 Observability</h3>
              <p>Integrated with Dynatrace OneAgent for comprehensive monitoring, logging, and automated remediation.</p>
            </div>
          </Col>
        </Row>
        
        <Row className="mt-5">
          <Col md={6}>
            <div className="text-center">
              <h4>Features</h4>
              <ul className="list-unstyled">
                <li>✅ User registration and authentication</li>
                <li>✅ Product catalog browsing</li>
                <li>✅ Shopping cart functionality</li>
                <li>✅ Order processing</li>
                <li>✅ Payment simulation</li>
              </ul>
            </div>
          </Col>
          <Col md={6}>
            <div className="text-center">
              <h4>Testing Scenarios</h4>
              <ul className="list-unstyled">
                <li>🔧 Configuration drift detection</li>
                <li>🔧 High load testing</li>
                <li>🔧 Database connectivity issues</li>
                <li>🔧 Service failure simulation</li>
                <li>🔧 Performance monitoring</li>
              </ul>
            </div>
          </Col>
        </Row>
      </Container>
    </div>
  );
};

export default Home;
