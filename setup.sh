#!/bin/bash

# VSS Sports UI Setup Script
# This script configures the environment for local development or Docker deployment

echo "VSS Sports Analysis UI - Setup"
echo "================================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "✓ .env file created"
else
    echo "✓ .env file already exists"
fi

echo ""
echo "Configuration Options:"
echo "1. Local Development (Vite dev server)"
echo "2. Docker Deployment"
echo ""
read -p "Select option (1 or 2): " -n 1 -r
echo ""

if [ "$REPLY" = "1" ]; then
    echo ""
    echo "Setting up for local development..."
    echo ""
    read -p "Enter VSS Backend URL (default: http://localhost:8000): " VSS_URL
    VSS_URL=${VSS_URL:-http://localhost:8000}
    
    # Update .env file
    sed -i "s|^VITE_VSS_API_URL=.*|VITE_VSS_API_URL=$VSS_URL|" .env
    echo "✓ VITE_VSS_API_URL set to $VSS_URL"
    
    echo ""
    echo "To start the development server:"
    echo "  npm install"
    echo "  npm run dev"
    echo ""
    echo "The application will be available at http://localhost:3000"
    
elif [ "$REPLY" = "2" ]; then
    echo ""
    echo "Setting up for Docker deployment..."
    echo ""
    echo "Docker Compose will automatically configure:"
    echo "  - VITE_VSS_API_URL=http://host.docker.internal:8000"
    echo "  - Port mapping: 8080:80"
    echo ""
    echo "To deploy with Docker:"
    echo "  docker-compose up -d"
    echo ""
    echo "The application will be available at http://localhost:8080"
else
    echo "Invalid option. Exiting."
    exit 1
fi

echo ""
echo "Setup complete!"
