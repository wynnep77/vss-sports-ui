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
        print_info "The script will NOT install or modify NVIDIA drivers to preserve your existing setup."
        return 1
    fi
}

################################################################################
# Cleanup Functions
################################################################################

cleanup_old_installation() {
    print_header "Cleaning Up Old Installations"

    # Check for old VSS installation in home directory
    OLD_VSS_DIR="$HOME/video-search-and-summarization"

    if [ -d "$OLD_VSS_DIR" ]; then
        print_warning "Found old VSS installation at $OLD_VSS_DIR"
        print_info "This may cause conflicts with the new installation"
        read -p "Remove old installation? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing old installation..."
            sudo rm -rf "$OLD_VSS_DIR"
            print_success "Old installation removed"
        else
            print_warning "Keeping old installation - this may cause issues"
        fi
    else
        print_success "No old installation found"
    fi
}

################################################################################
# Environment Configuration
################################################################################

configure_all_env_files() {
    print_header "Configuring All Environment Files"

    # Create .env file in vss-sports-ui directory
    print_info "Creating .env file in vss-sports-ui directory..."
    
    if [ -z "$SPORTS_UI_DIR" ]; then
        SPORTS_UI_DIR="$INSTALL_DIR/vss-sports-ui"
    fi
    
    SPORTS_UI_ENV="$SPORTS_UI_DIR/.env"
    
    # Create .env from template if it doesn't exist
    if [ ! -f "$SPORTS_UI_ENV" ]; then
        if [ -f "$SPORTS_UI_DIR/.env.template" ]; then
            cp "$SPORTS_UI_DIR/.env.template" "$SPORTS_UI_ENV"
            print_success "Created .env from template"
        else
            print_error ".env.template not found"
            exit 1
        fi
    fi
    
    # Update the .env file with HOST_IP and NGC_API_KEY
    sed -i "s/^HOST_IP=.*/HOST_IP=$HOST_IP/" "$SPORTS_UI_ENV"
    sed -i "s/^NGC_API_KEY=.*/NGC_API_KEY=$NGC_API_KEY/" "$SPORTS_UI_ENV"
    
    # Set VSS_APPS_DIR and VSS_DATA_DIR
    sed -i "s|^VSS_APPS_DIR=.*|VSS_APPS_DIR=$INSTALL_DIR/video-search-and-summarization/deploy/docker|" "$SPORTS_UI_ENV"
    sed -i "s|^VSS_DATA_DIR=.*|VSS_DATA_DIR=$INSTALL_DIR/vss-data|" "$SPORTS_UI_ENV"
    
    print_success "Configured vss-sports-ui/.env"

    # Configure dev-profile-base .env
    PROFILE_ENV="$INSTALL_DIR/video-search-and-summarization/deploy/docker/developer-profiles/dev-profile-base/.env"

    if [ -f "$PROFILE_ENV" ]; then
        cp "$PROFILE_ENV" "${PROFILE_ENV}.backup"
        
        sed -i "s/^HOST_IP=.*/HOST_IP=$HOST_IP/" "$PROFILE_ENV"
        sed -i "s/^NGC_API_KEY=.*/NGC_API_KEY=$NGC_API_KEY/" "$PROFILE_ENV"
        
        # Set derived URLs
        LLM_PORT=30081
        VLM_PORT=30082
        VST_PORT=30888
        
        sed -i "s/^LLM_BASE_URL=.*/LLM_BASE_URL=http:\/\/\${HOST_IP}:${LLM_PORT}/" "$PROFILE_ENV"
        sed -i "s/^VLM_BASE_URL=.*/VLM_BASE_URL=http:\/\/\${HOST_IP}:${VLM_PORT}/" "$PROFILE_ENV"
        sed -i "s/^VST_INTERNAL_URL=.*/VST_INTERNAL_URL=http:\/\/\${HOST_IP}:${VST_PORT}/" "$PROFILE_ENV"
        sed -i "s/^VST_EXTERNAL_URL=.*/VST_EXTERNAL_URL=http:\/\/\${HOST_IP}:${VST_PORT}/" "$PROFILE_ENV"
        
        print_success "Configured dev-profile-base/.env"
    else
        print_error "dev-profile-base/.env not found"
        exit 1
    fi

    # Configure overrides.env
    OVERRIDES_ENV="$INSTALL_DIR/video-search-and-summarization/deploy/docker/developer-profiles/dev-profile-base/overrides.env"

    if [ -f "$OVERRIDES_ENV" ]; then
        cp "$OVERRIDES_ENV" "${OVERRIDES_ENV}.backup"
        
        sed -i "s|VSS_APPS_DIR=\"/path/to/deploy/docker\"|VSS_APPS_DIR=\"$INSTALL_DIR/video-search-and-summarization/deploy/docker\"|" "$OVERRIDES_ENV"
        sed -i "s|VSS_DATA_DIR=\"/path/to/vss-apps-data\"|VSS_DATA_DIR=\"$INSTALL_DIR/vss-data\"|" "$OVERRIDES_ENV"
        sed -i "s|HOST_IP='<HOST_IP>'|HOST_IP='$HOST_IP'|" "$OVERRIDES_ENV"
        sed -i "s|EXTERNAL_IP=\${HOST_IP}|EXTERNAL_IP=$HOST_IP|" "$OVERRIDES_ENV"
        sed -i "s|NGC_CLI_API_KEY=\${NGC_CLI_API_KEY:-}|NGC_CLI_API_KEY=$NGC_API_KEY|" "$OVERRIDES_ENV"
        sed -i "s|NVIDIA_API_KEY=\${NVIDIA_API_KEY:-}|NVIDIA_API_KEY=$NGC_API_KEY|" "$OVERRIDES_ENV"
        sed -i "s|HARDWARE_PROFILE=H100|HARDWARE_PROFILE=RTXPRO6000BW|" "$OVERRIDES_ENV"
        
        print_success "Configured overrides.env"
    else
        print_error "overrides.env not found"
        exit 1
    fi

    # Copy and configure service .env files
    print_info "Configuring service .env files..."

    SERVICES_SOURCE_DIR="$INSTALL_DIR/video-search-and-summarization/deploy/docker/services"
    SERVICES_DEST_DIR="$INSTALL_DIR/video-search-and-summarization/deploy/docker/services"

    # List of env files to copy
    ENV_FILES=(
        "agent/agent.env"
        "alert/alert.env"
        "rtvi/rtvi.env"
        "vios/vst.env"
        "infra/infra.env"
        "nim/nim.env"
        "ui/ui.env"
        "nvstreamer/.env"
        "video-summarization/lvs.env"
    )

    for env_file in "${ENV_FILES[@]}"; do
        source_file="$SERVICES_SOURCE_DIR/$env_file"
        dest_file="$SERVICES_DEST_DIR/$env_file"

        if [ -f "$source_file" ]; then
            mkdir -p "$(dirname "$dest_file")"
            cp "$source_file" "$dest_file"
            print_success "Copied $env_file"
        else
            print_warning "Skipping $env_file (not found at $source_file)"
        fi
    done

    print_success "All environment files configured"
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

    print_warning "Skipping NVIDIA driver installation to preserve your existing setup"
    print_info "Your current NVIDIA drivers will be preserved"

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

    print_success "System dependencies installed (NVIDIA drivers preserved)"
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

    # Copy the .env file from vss-sports-ui to VSS Blueprint location
    print_info "Copying .env file to VSS Blueprint location..."

    # Use the SPORTS_UI_DIR from main()
    if [ -z "$SPORTS_UI_DIR" ]; then
        SPORTS_UI_DIR="$INSTALL_DIR/vss-sports-ui"
    fi

    SPORTS_UI_ENV="$SPORTS_UI_DIR/.env"
    PROFILE_DIR="$INSTALL_DIR/video-search-and-summarization/deploy/docker/developer-profiles/dev-profile-base"
    VSS_ENV_FILE="$PROFILE_DIR/.env"

    # Check if vss-sports-ui .env exists
    if [ -f "$SPORTS_UI_ENV" ]; then
        print_info "Found .env in vss-sports-ui directory"
        # Copy it to VSS Blueprint location
        cp "$SPORTS_UI_ENV" "$VSS_ENV_FILE"
        print_success "Copied .env to VSS Blueprint location"
    else
        print_error "Environment file not found in vss-sports-ui directory"
        print_info "Required location: $SPORTS_UI_ENV"
        print_info ""
        print_info "The configure_all_env_files function should have created this"
        print_info "Please check the script output for errors"
        exit 1
    fi

    print_success "VSS environment configured"
}

deploy_vss_backend() {
    print_header "Deploying VSS Backend"

    cd "$INSTALL_DIR/video-search-and-summarization/deploy/docker"

    # Export VSS_APPS_DIR for Docker Compose
    export VSS_APPS_DIR="$INSTALL_DIR/video-search-and-summarization/services/ui"
    print_info "Setting VSS_APPS_DIR=$VSS_APPS_DIR"

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

    # Check if we're running from within vss-sports-ui directory
    if [ "$(basename $(pwd))" = "vss-sports-ui" ]; then
        print_info "Already in vss-sports-ui directory"
        SPORTS_UI_DIR="$(pwd)"
    elif [ -d "vss-sports-ui" ]; then
        print_warning "Sports UI directory already exists. Pulling latest changes..."
        cd vss-sports-ui
        git pull
        SPORTS_UI_DIR="$(pwd)"
    else
        print_info "Cloning Sports UI repository..."
        git clone "$FRONTEND_REPO"
        cd vss-sports-ui
        SPORTS_UI_DIR="$(pwd)"
    fi

    print_success "Sports UI cloned/updated at $SPORTS_UI_DIR"
}

deploy_sports_frontend() {
    print_header "Deploying Sports Analysis Frontend"

    # Use the detected Sports UI directory
    if [ -z "$SPORTS_UI_DIR" ]; then
        SPORTS_UI_DIR="$INSTALL_DIR/vss-sports-ui"
    fi

    cd "$SPORTS_UI_DIR"

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

    print_warning "IMPORTANT: This script will NOT install or modify NVIDIA drivers"
    print_info "Your existing NVIDIA drivers will be preserved"
    print_info "If you need to install drivers, do so manually before running this script"
    echo ""

    # Detect if running from within vss-sports-ui directory
    CURRENT_DIR="$(pwd)"
    if [ "$(basename $CURRENT_DIR)" = "vss-sports-ui" ]; then
        print_info "Running from within vss-sports-ui directory"
        # If running from vss-sports-ui, use parent as install dir
        INSTALL_DIR="$(dirname $CURRENT_DIR)"
        SPORTS_UI_DIR="$CURRENT_DIR"
    else
        # If running from elsewhere, use vss-deployment
        INSTALL_DIR="$HOME/vss-deployment"
        SPORTS_UI_DIR="$INSTALL_DIR/vss-sports-ui"
    fi

    # Special case: if the parent directory is the user's home, keep vss-sports-ui in home
    if [ "$(dirname $CURRENT_DIR)" = "$HOME" ] && [ "$(basename $CURRENT_DIR)" = "vss-sports-ui" ]; then
        INSTALL_DIR="$HOME"
        SPORTS_UI_DIR="$HOME/vss-sports-ui"
    fi

    echo "This script will install:"
    echo "  1. NVIDIA VSS Blueprint backend"
    echo "  2. Sports Analysis frontend"
    echo ""
    echo "Current directory: $CURRENT_DIR"
    echo "Installation directory: $INSTALL_DIR"
    echo "Sports UI directory: $SPORTS_UI_DIR"
    echo "Expected .env location: $SPORTS_UI_DIR/.env"
    echo ""
    echo "Requirements:"
    echo "  - Ubuntu OS"
    echo "  - RTX PRO 6000 GPU (or compatible)"
    echo "  - NVIDIA NGC API key"
    echo "  - Internet connection"
    echo "  - NVIDIA drivers (already installed - will NOT be modified)"
    echo ""

    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi

    # Step 0: Cleanup old installations
    cleanup_old_installation

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

    # Step 6: Configure all .env files
    configure_all_env_files

    # Step 7: Setup VSS Blueprint
    setup_vss_blueprint

    # Step 8: Deploy VSS Backend
    if ! deploy_vss_backend; then
        print_error "VSS backend deployment failed"
        exit 1
    fi

    # Step 9: Setup Sports Frontend
    setup_sports_frontend

    # Step 10: Deploy Sports Frontend
    deploy_sports_frontend

    # Step 11: Verify deployment
    verify_deployment

    # Step 12: Print summary
    print_summary
}

# Run main function
main
