#!/bin/bash
echo "📥 Pulling latest changes from repository..."
git pull

echo "🔄 Stopping Dynatrace CI/CD Demo containers..."
docker-compose down

echo "🗑️ Do you want to delete all data and start fresh? (y/N)"
read -p "This will remove all database data: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️ Removing volumes and starting fresh..."
    docker-compose down -v
    echo "✅ Volumes removed. Database will be reinitialized."
else
    echo "📊 Keeping existing data..."
fi

echo "🚀 Rebuilding and starting containers..."
docker-compose up -d --build

echo "⏳ Waiting for services to be ready..."
sleep 10

echo "📊 Container status:"
docker-compose ps

echo "📝 Recent logs:"
docker-compose logs --tail=10

echo "✅ Deployment complete!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔗 API Gateway: http://localhost:4000"