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
VSS_PUBLIC_HOST=$HOST_IP
VSS_PUBLIC_PORT=8000
VSS_PUBLIC_HTTP_PROTOCOL=http

# NGC Configuration
NGC_CLI_API_KEY=$NGC_API_KEY
NVIDIA_API_KEY=$NGC_API_KEY

# LLM Configuration
LLM_MODE=nim
LLM_NAME=nemotron-3.5-lightning-30b-a3b
LLM_DEVICE_ID=1
LLM_BASE_URL=http://$HOST_IP:30081
LLM_MODEL_TYPE=nim

# VLM Configuration
VLM_MODE=nim
VLM_NAME=rt-vlm
VLM_DEVICE_ID=0
VLM_BASE_URL=http://$HOST_IP:30082
VLM_MODEL_TYPE=nim
RTVI_VLM_MODEL_TO_USE=rt-vlm

# VST Configuration
VST_MODE=nim
VST_NAME=vst
VST_IP=$HOST_IP
VST_PORT=30888
VST_EXTERNAL_URL=http://$HOST_IP:30888
VST_MCP_URL=

# Service Ports
LLM_PORT=30081
VLM_PORT=30082
VST_PORT=30888
VSS_AGENT_PORT=8000
RTVI_CV_PORT=30083

# VSS Apps Directory
VSS_APPS_DIR=$DEPLOY_DIR
VSS_DATA_DIR=$VSS_DIR/data

# VSS Agent Configuration
VSS_AGENT_VERSION=1.0.0
VSS_AGENT_CONFIG_FILE=
VSS_AGENT_EXTERNAL_URL=http://$HOST_IP:8000
VSS_AGENT_REPORTS_BASE_URL=http://$HOST_IP:8000
VSS_AGENT_TEMPLATE_PATH=
VSS_AGENT_TEMPLATE_NAME=
VSS_VA_MCP_CONFIG_FILE=
LVS_BACKEND_URL=
VSS_AUTO_CALIBRATION_HOST_PORT=

# Additional Configuration
MODE=2d
STREAM_TYPE=kafka
NUM_SENSORS=0
NUM_STREAMS=1
ENABLE_AUDIO=false
HARDWARE_PROFILE=RTXPRO6000BW
SAMPLE_VIDEO_DATASET=
AI_BRIDGE_ENDPOINT=
BP_PROFILE=bp_developer_base
RESERVED_DEVICE_IDS=
FIXED_SHARED_DEVICE_IDS=
ELASTICSEARCH_ILM_MIN_AGE=4h

# Elasticsearch Configuration
ELASTIC_SEARCH_ENDPOINT=http://$HOST_IP:9200
ELASTIC_SEARCH_INDEX=vss-index
COSMOS_EMBED_ENDPOINT=

# Evaluation Configuration
EVAL_DIR=$VSS_DIR/data/eval
EVAL_OUTPUT_DIR=$VSS_DIR/data/eval/results
DATASET_DIR=$VSS_DIR/data/dataset
DATASET_FILE_NAME=dataset.json
REPORT_REFERENCE_BASE_DIR=$VSS_DIR/data/references
EVAL_LLM_JUDGE_NAME=

# Grafana Configuration
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin

# NVStreamer Configuration
NVSTREAMER_IP=$HOST_IP
NVSTREAMER_HTTP_PORT=7000
NVSTREAMER_CONFIG_DIR=/opt/nvstreamer/config
NVSTREAMER_INSTALL_ADDITIONAL_PACKAGES=

# Adaptor Configuration
ADAPTOR_IP=$HOST_IP
ADAPTOR_USER=admin
ADAPTOR_PASSWORD=admin

# Database Configuration
GRAPH_DB_PASSWORD=graphdb
ARANGO_DB_PASSWORD=arangodb
MINIO_PASSWORD=minioadmin
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
