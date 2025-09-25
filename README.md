# Dynatrace CI/CD Demo Application

A complete microservices e-commerce application designed for testing Dynatrace CI/CD automation capabilities.

##  Architecture

### Frontend
- **React** with Bootstrap for modern UI
- **Nginx** for serving static files
- **Port:** 3000

### Backend Services
- **API Gateway** (Node.js) - Port 4000
- **User Service** (Node.js) - Port 3001
- **Product Service** (Node.js) - Port 3002
- **Order Service** (Node.js) - Port 3003
- **Payment Service** (Node.js) - Port 3004

### Database & Caching
- **PostgreSQL** - Primary database
- **Redis** - Caching layer

##  Quick Start

### Prerequisites
- Docker & Docker Compose
- Node.js 18+
- kubectl (for Kubernetes deployment)
- Azure CLI (for Azure deployment)

### Local Development
`ash
# Install dependencies
npm install

# Start all services
docker-compose up -d

# Access the application
open http://localhost:3000
`

### Azure Deployment
`ash
# Deploy to Azure Kubernetes Service
./scripts/azure-deploy.sh
`

##  Project Structure

`
 frontend/                 # React frontend application
 backend/                  # Microservices
    api-gateway/         # API Gateway service
    user-service/        # User management
    product-service/     # Product catalog
    order-service/       # Order processing
    payment-service/     # Payment handling
 database/                # Database initialization scripts
 k8s/                     # Kubernetes manifests
 harness/                 # Harness CI/CD configurations
 dynatrace/              # Dynatrace monitoring configs
 scripts/                # Deployment and utility scripts
 docker-compose.yml      # Local development setup
`

##  CI/CD Pipeline

### Harness Pipeline Stages
1. **Build** - Docker image creation
2. **Deploy** - Kubernetes deployment
3. **Test** - Automated testing
4. **Validation** - Dynatrace quality gates

### Dynatrace Integration
- **Monitoring** - Application performance monitoring
- **Quality Gates** - Automated quality validation
- **CI/CD Automation** - Pipeline integration

##  Test Scenarios

The application includes various test scenarios for CI/CD automation:
- Normal user flow
- Configuration drift detection
- High load testing
- Database failure simulation
- Service degradation testing

##  Monitoring

- **Dynatrace** - Full-stack monitoring
- **Custom Dashboards** - E-commerce specific metrics
- **Alerting** - Automated incident response

##  Development

### Adding New Features
1. Create feature branch
2. Implement changes
3. Test locally with Docker
4. Push to GitHub
5. Harness pipeline automatically builds and deploys

### Database Changes
1. Update database/init.sql
2. Test with local PostgreSQL
3. Deploy to Azure Database for PostgreSQL

##  License

MIT License - See LICENSE file for details

##  Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

##  Support

For questions or issues:
- Create an issue in this repository
- Contact: sebastian.moscoso@dynatrace.com

---

**Built for Dynatrace CI/CD Automation Certification**
