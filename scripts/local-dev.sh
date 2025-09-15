#!/bin/bash

# Local Development Setup Script
# Usage: ./scripts/local-dev.sh [start|stop|restart|logs]

set -e

ACTION=${1:-"start"}

case $ACTION in
    "start")
        echo "🚀 Starting PCI application locally..."
        cd PCI-backend
        echo "📋 Starting database and services..."
        docker-compose up -d
        echo "✅ Services started!"
        echo "📊 Service URLs:"
        echo "Frontend: http://localhost:3000"
        echo "Backend: http://localhost:3001"
        echo "Database Admin: http://localhost:8000"
        echo ""
        echo "🔍 To view logs: ./scripts/local-dev.sh logs"
        ;;
    
    "stop")
        echo "🛑 Stopping PCI application..."
        cd PCI-backend
        docker-compose down
        echo "✅ Services stopped!"
        ;;
    
    "restart")
        echo "🔄 Restarting PCI application..."
        cd PCI-backend
        docker-compose down
        docker-compose up -d
        echo "✅ Services restarted!"
        ;;
    
    "logs")
        echo "📋 Showing logs (Ctrl+C to exit)..."
        cd PCI-backend
        docker-compose logs -f
        ;;
    
    "status")
        echo "📊 Service Status:"
        cd PCI-backend
        docker-compose ps
        ;;
    
    "clean")
        echo "🧹 Cleaning up containers and volumes..."
        cd PCI-backend
        docker-compose down -v --remove-orphans
        docker system prune -f
        echo "✅ Cleanup completed!"
        ;;
    
    *)
        echo "Usage: $0 [start|stop|restart|logs|status|clean]"
        echo ""
        echo "Commands:"
        echo "  start    - Start all services"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  logs     - Show live logs"
        echo "  status   - Show service status"
        echo "  clean    - Clean up containers and volumes"
        exit 1
        ;;
esac
