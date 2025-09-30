#!/bin/bash
echo "🔄 Stopping Dynatrace CI/CD Demo containers..."
docker-compose down

echo "🚀 Rebuilding and starting containers..."
docker-compose up -d --build

echo "📊 Container status:"
docker-compose ps

echo "📝 Recent logs:"
docker-compose logs --tail=10