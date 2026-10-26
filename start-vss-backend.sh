#!/bin/bash

# VSS Blueprint Startup Script
# This script configures required environment variables and starts the VSS Blueprint

echo "VSS Blueprint Startup Script"
echo "============================"
echo ""

# Configuration
VSS_DIR="/home/demouser/video-search-and-summarization"
DEPLOY_DIR="$VSS_DIR/deploy/docker"

# Check if VSS Blueprint exists
if [ ! -d "$VSS_DIR" ]; then
    echo "Error: VSS Blueprint not found at $VSS_DIR"
    echo "Please install VSS Blueprint first"
    exit 1
fi

echo "✓ VSS Blueprint found at $VSS_DIR"
echo ""

# Detect host IP
HOST_IP=$(hostname -I | awk '{print $1}')
echo "Detected Host IP: $HOST_IP"
echo ""

# Prompt for NGC API key if not set
if [ -z "$NGC_API_KEY" ]; then
    echo "Enter your NVIDIA NGC API Key (or press Enter to skip):"
    read -s NGC_API_KEY
    echo ""
    if [ -z "$NGC_API_KEY" ]; then
        echo "⚠ No API key provided - some features may not work"
    fi
fi

# Create/Update .env file in deploy/docker directory
cd "$DEPLOY_DIR"

echo "Configuring environment variables..."
cat > .env << EOF
# Network Configuration
HOST_IP=$HOST_IP
EXTERNAL_IP=$HOST_IP
INTERNAL_IP=$HOST_IP

# NGC Configuration
NGC_CLI_API_KEY=$NGC_API_KEY
NVIDIA_API_KEY=$NGC_API_KEY

# LLM Configuration
LLM_MODE=nim
LLM_NAME=nemotron-3.5-lightning-30b-a3b
LLM_DEVICE_ID=1

# VLM Configuration
VLM_MODE=nim
VLM_NAME=rt-vlm
VLM_DEVICE_ID=0

# VST Configuration
VST_MODE=nim
VST_NAME=vst

# Service Ports
LLM_PORT=30081
VLM_PORT=30082
VST_PORT=30888
VSS_AGENT_PORT=8000

# VSS Apps Directory
VSS_APPS_DIR=$DEPLOY_DIR
VSS_DATA_DIR=$VSS_DIR/data

# Additional Configuration
MODE=2d
STREAM_TYPE=kafka
NUM_SENSORS=0
ENABLE_AUDIO=false
HARDWARE_PROFILE=RTXPRO6000BW
SAMPLE_VIDEO_DATASET=
AI_BRIDGE_ENDPOINT=
BP_PROFILE=bp_developer_base
RESERVED_DEVICE_IDS=
FIXED_SHARED_DEVICE_IDS=
ELASTICSEARCH_ILM_MIN_AGE=4h
EOF

echo "✓ Environment variables configured"
echo ""

# Create data directory if it doesn't exist
mkdir -p "$VSS_DIR/data"
echo "✓ Data directory created"
echo ""

# Start VSS Blueprint
echo "Starting VSS Blueprint services..."
docker compose up -d

echo ""
echo "Waiting for services to start..."
sleep 10

# Check if services are running
echo ""
echo "Checking service status..."
docker compose ps

echo ""
echo "Testing VSS backend health..."
sleep 5
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✓ VSS backend is healthy"
else
    echo "⚠ VSS backend may still be starting up"
    echo "  Check with: docker compose logs -f"
fi

echo ""
echo "VSS Blueprint startup complete!"
echo "VSS backend should be available at http://$HOST_IP:8000"
