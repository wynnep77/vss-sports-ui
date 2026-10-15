#!/bin/bash

################################################################################
# VSS Sports Analysis - Complete Installation Script
# This script installs the NVIDIA VSS Blueprint backend and the Sports UI frontend
# for Ubuntu systems with RTX PRO 6000 GPU
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
INSTALL_DIR="$HOME/vss-deployment"
VSS_REPO="https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization.git"
FRONTEND_REPO="https://github.com/wynnep77/vss-sports-ui.git"
NGC_API_KEY=""
HOST_IP=""

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default_value="$3"
    local input_value

    if [ -n "$default_value" ]; then
        read -p "$prompt [$default_value]: " input_value
        eval "$var_name=\"\${input_value:-$default_value}\""
    else
        read -p "$prompt: " input_value
        eval "$var_name=\"\$input_value\""
    fi
}

prompt_password() {
    local prompt="$1"
    local var_name="$2"
    local input_value

    read -s -p "$prompt: " input_value
    echo
    eval "$var_name=\"\$input_value\""
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_gpu() {
    print_header "Checking GPU"
    if check_command nvidia-smi; then
        print_success "NVIDIA driver detected"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
        return 0
    else
        print_error "NVIDIA driver not found. Please install NVIDIA drivers first."
        print_info "Visit: https://www.nvidia.com/Download/index.aspx"
        return 1
    fi
}

################################################################################
# Installation Steps
################################################################################

install_docker() {
    print_header "Installing Docker"

    if check_command docker; then
        print_success "Docker is already installed"
        docker --version
    else
        print_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        print_success "Docker installed"
    fi

    if check_command docker-compose; then
        print_success "Docker Compose is already installed"
        docker-compose --version
    else
        print_info "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        print_success "Docker Compose installed"
    fi
}

install_dependencies() {
    print_header "Installing System Dependencies"

    sudo apt-get update
    sudo apt-get install -y \
        curl \
        git \
        wget \
        python3 \
        python3-pip \
        build-essential \
        libcairo2-dev \
        pkg-config \
        python3-dev

    print_success "System dependencies installed"
}

prompt_api_keys() {
    print_header "API Key Configuration"

    print_warning "You need an NVIDIA API key to use the NIM microservices."
    print_info "Get your API key from: https://build.nvidia.com/"
    print_info "Or from NGC: https://org.ngc.nvidia.com/setup/api-keys"

    prompt_password "Enter your NVIDIA NGC API Key" NGC_API_KEY

    if [ -z "$NGC_API_KEY" ]; then
        print_error "API key is required. Please run the script again with a valid API key."
        exit 1
    fi

    print_success "API key received"
}

detect_host_ip() {
    print_header "Network Configuration"

    # Try to detect the host IP automatically
    HOST_IP=$(hostname -I | awk '{print $1}')

    if [ -z "$HOST_IP" ]; then
        HOST_IP="127.0.0.1"
    fi

    prompt_input "Detected host IP" HOST_IP "$HOST_IP"
    print_success "Using host IP: $HOST_IP"
}

setup_vss_blueprint() {
    print_header "Setting up NVIDIA VSS Blueprint"

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    if [ -d "video-search-and-summarization" ]; then
        print_warning "VSS Blueprint directory already exists. Pulling latest changes..."
        cd video-search-and-summarization
        git pull
    else
        print_info "Cloning VSS Blueprint repository..."
        git clone "$VSS_REPO"
        cd video-search-and-summarization
    fi

    print_success "VSS Blueprint cloned"

    # Create environment file for dev-profile-base
    print_info "Configuring VSS environment..."

    PROFILE_DIR="$INSTALL_DIR/video-search-and-summarization/deploy/docker/developer-profiles/dev-profile-base"
    ENV_FILE="$PROFILE_DIR/.env"

    if [ ! -f "$ENV_FILE" ]; then
        print_error "Environment file not found at $ENV_FILE"
        print_info "Please ensure you're using a valid VSS Blueprint version"
        exit 1
    fi

    # Backup original env file
    cp "$ENV_FILE" "${ENV_FILE}.backup"

    # Update environment variables
    sed -i "s/^HOST_IP=.*/HOST_IP=$HOST_IP/" "$ENV_FILE"
    sed -i "s/^NGC_API_KEY=.*/NGC_API_KEY=$NGC_API_KEY/" "$ENV_FILE"

    # Set derived variables
    LLM_PORT=30081
    VLM_PORT=30082
    VST_PORT=30888
    VSS_AGENT_PORT=8000
    VSS_APPS_DIR="$INSTALL_DIR/video-search-and-summarization/services/ui"

    sed -i "s/^LLM_BASE_URL=.*/LLM_BASE_URL=http:\/\/\${HOST_IP}:${LLM_PORT}/" "$ENV_FILE"
    sed -i "s/^VLM_BASE_URL=.*/VLM_BASE_URL=http:\/\/\${HOST_IP}:${VLM_PORT}/" "$ENV_FILE"
    sed -i "s/^VST_INTERNAL_URL=.*/VST_INTERNAL_URL=http:\/\/\${HOST_IP}:${VST_PORT}/" "$ENV_FILE"
    sed -i "s/^VST_EXTERNAL_URL=.*/VST_EXTERNAL_URL=http:\/\/\${HOST_IP}:${VST_PORT}/" "$ENV_FILE"

    # Add VSS_APPS_DIR if not present
    if ! grep -q "^VSS_APPS_DIR=" "$ENV_FILE"; then
        echo "VSS_APPS_DIR=$VSS_APPS_DIR" >> "$ENV_FILE"
    else
        sed -i "s|^VSS_APPS_DIR=.*|VSS_APPS_DIR=$VSS_APPS_DIR|" "$ENV_FILE"
    fi

    print_success "VSS environment configured"
}

deploy_vss_backend() {
    print_header "Deploying VSS Backend"

    cd "$INSTALL_DIR/video-search-and-summarization/deploy/docker"

    print_info "Starting VSS services with Docker Compose..."
    print_warning "This may take 10-20 minutes on first run (downloading Docker images)"

    # Start the services
    docker-compose -f compose.yml --env-file ../developer-profiles/dev-profile-base/.env up -d

    print_success "VSS backend services started"
    print_info "Waiting for services to be ready..."

    # Wait for services to be healthy
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:8000/health > /dev/null 2>&1; then
            print_success "VSS agent is ready!"
            break
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done

    if [ $attempt -eq $max_attempts ]; then
        print_error "VSS agent did not start within expected time"
        print_info "Check logs with: cd $INSTALL_DIR/video-search-and-summarization/deploy/docker && docker-compose logs"
        return 1
    fi

    return 0
}

setup_sports_frontend() {
    print_header "Setting up Sports Analysis Frontend"

    cd "$INSTALL_DIR"

    if [ -d "vss-sports-ui" ]; then
        print_warning "Sports UI directory already exists. Pulling latest changes..."
        cd vss-sports-ui
        git pull
    else
        print_info "Cloning Sports UI repository..."
        git clone "$FRONTEND_REPO"
        cd vss-sports-ui
    fi

    print_success "Sports UI cloned"
}

deploy_sports_frontend() {
    print_header "Deploying Sports Analysis Frontend"

    cd "$INSTALL_DIR/vss-sports-ui"

    print_info "Building Docker image..."
    docker build -t vss-sports-ui:latest .

    print_info "Stopping existing container (if running)..."
    docker stop vss-sports-ui 2>/dev/null || true
    docker rm vss-sports-ui 2>/dev/null || true

    print_info "Starting Sports UI container..."
    docker run -d \
        --name vss-sports-ui \
        -p 80:80 \
        -e VITE_API_BASE_URL=http://$HOST_IP:8000 \
        --add-host=host.docker.internal:host-gateway \
        --restart unless-stopped \
        vss-sports-ui:latest

    print_success "Sports UI deployed on port 80"
}

verify_deployment() {
    print_header "Verifying Deployment"

    print_info "Checking VSS Agent..."
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        print_success "VSS Agent is running on port 8000"
    else
        print_error "VSS Agent is not responding"
    fi

    print_info "Checking Sports UI..."
    if curl -s http://localhost > /dev/null 2>&1; then
        print_success "Sports UI is running on port 80"
    else
        print_error "Sports UI is not responding"
    fi

    print_info "Checking Docker containers..."
    docker ps --filter "name=vss" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

print_summary() {
    print_header "Installation Complete!"

    echo -e "${GREEN}✓ VSS Backend: http://$HOST_IP:8000${NC}"
    echo -e "${GREEN}✓ Sports UI: http://$HOST_IP${NC}"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  View VSS logs:    cd $INSTALL_DIR/video-search-and-summarization/deploy/docker && docker-compose logs -f"
    echo "  View UI logs:      docker logs -f vss-sports-ui"
    echo "  Stop VSS:         cd $INSTALL_DIR/video-search-and-summarization/deploy/docker && docker-compose down"
    echo "  Stop UI:          docker stop vss-sports-ui"
    echo "  Restart UI:       docker restart vss-sports-ui"
    echo ""
    echo -e "${YELLOW}Note: First-time deployment may take additional time as models are downloaded.${NC}"
    echo -e "${YELLOW}Monitor the VSS logs to see when models are fully loaded.${NC}"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    print_header "VSS Sports Analysis - Installation Script"
    echo "This script will install:"
    echo "  1. NVIDIA VSS Blueprint backend"
    echo "  2. Sports Analysis frontend"
    echo ""
    echo "Requirements:"
    echo "  - Ubuntu OS"
    echo "  - RTX PRO 6000 GPU (or compatible)"
    echo "  - NVIDIA NGC API key"
    echo "  - Internet connection"
    echo ""

    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    # Step 1: Check GPU
    if ! check_gpu; then
        exit 1
    fi

    # Step 2: Install Docker
    install_docker

    # Step 3: Install system dependencies
    install_dependencies

    # Step 4: Prompt for API keys
    prompt_api_keys

    # Step 5: Detect host IP
    detect_host_ip

    # Step 6: Setup VSS Blueprint
    setup_vss_blueprint

    # Step 7: Deploy VSS Backend
    if ! deploy_vss_backend; then
        print_error "VSS backend deployment failed"
        exit 1
    fi

    # Step 8: Setup Sports Frontend
    setup_sports_frontend

    # Step 9: Deploy Sports Frontend
    deploy_sports_frontend

    # Step 10: Verify deployment
    verify_deployment

    # Step 11: Print summary
    print_summary
}

# Run main function
main
