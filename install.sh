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

# Global variables for discovered paths (will be set during configuration)
VSS_DIR=""
VSS_APPS_DIR=""
PROFILE_ENV=""
VSS_DATA_DIR=""

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
        
        # Store current driver version for verification later
        CURRENT_DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
        print_info "Current driver version: $CURRENT_DRIVER_VERSION"
        
        # Store current kernel version for verification later
        CURRENT_KERNEL_VERSION=$(uname -r)
        print_info "Current kernel version: $CURRENT_KERNEL_VERSION"
        
        # Export these for later verification
        export CURRENT_DRIVER_VERSION
        export CURRENT_KERNEL_VERSION
        
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
            
            # Update the .env file with HOST_IP and NGC_API_KEY (using different delimiter)
            sed -i "s#HOST_IP=<your-server-ip>#HOST_IP=$HOST_IP#" "$SPORTS_UI_ENV"
            sed -i "s#EXTERNAL_IP=<your-server-ip>#EXTERNAL_IP=$HOST_IP#" "$SPORTS_UI_ENV"
            sed -i "s#INTERNAL_IP=<your-server-ip>#INTERNAL_IP=$HOST_IP#" "$SPORTS_UI_ENV"
            sed -i "s#NGC_API_KEY=<your-ngc-api-key>#NGC_API_KEY=$NGC_API_KEY#" "$SPORTS_UI_ENV"
        else
            print_error ".env.template not found"
            exit 1
        fi
    else
        # Update existing .env file
        sed -i "s#HOST_IP=<your-server-ip>#HOST_IP=$HOST_IP#" "$SPORTS_UI_ENV"
        sed -i "s#EXTERNAL_IP=<your-server-ip>#EXTERNAL_IP=$HOST_IP#" "$SPORTS_UI_ENV"
        sed -i "s#INTERNAL_IP=<your-server-ip>#INTERNAL_IP=$HOST_IP#" "$SPORTS_UI_ENV"
        sed -i "s#NGC_API_KEY=<your-ngc-api-key>#NGC_API_KEY=$NGC_API_KEY#" "$SPORTS_UI_ENV"
    fi
    
    print_success "Configured vss-sports-ui/.env"

    # Find the actual location of deployment templates
    print_info "Searching for deployment templates..."
    
    VSS_DIR="$INSTALL_DIR/video-search-and-summarization"
    
    # Search for developer-profiles directory, preferring docker over helm
    DEV_PROFILES_DIR=$(find "$VSS_DIR/deploy/docker" -type d -name "developer-profiles" 2>/dev/null | head -1)
    
    # If not found in docker, search anywhere but exclude helm and ensure it's the right structure
    if [ -z "$DEV_PROFILES_DIR" ]; then
        print_warning "Could not find developer-profiles in deploy/docker"
        print_info "Searching in other locations (excluding helm)..."
        DEV_PROFILES_DIR=$(find "$VSS_DIR" -type d -name "developer-profiles" 2>/dev/null | grep -v "/helm/" | head -1)
    fi
    
    if [ -z "$DEV_PROFILES_DIR" ]; then
        print_error "Could not find developer-profiles directory anywhere"
        print_info "Searched in: $VSS_DIR"
        print_info "Please ensure the VSS Blueprint is properly cloned"
        exit 1
    fi
    
    print_info "Found developer-profiles at: $DEV_PROFILES_DIR"
    
    # Verify it's the docker deployment (not helm)
    if echo "$DEV_PROFILES_DIR" | grep -q "/helm/"; then
        print_error "Found helm deployment instead of docker deployment"
        print_info "Location: $DEV_PROFILES_DIR"
        print_info "The script requires the docker deployment configuration"
        exit 1
    fi
    
    # Set VSS_APPS_DIR to the directory containing developer-profiles
    VSS_APPS_DIR=$(dirname "$DEV_PROFILES_DIR")
    
    # Validate VSS_APPS_DIR is set
    if [ -z "$VSS_APPS_DIR" ]; then
        print_error "VSS_APPS_DIR is not set (DEV_PROFILES_DIR: $DEV_PROFILES_DIR)"
        exit 1
    fi
    
    print_info "Setting VSS_APPS_DIR to: $VSS_APPS_DIR"
    
    # Find dev-profile-base directory
    PROFILE_DIR=""
    if [ -d "$DEV_PROFILES_DIR/dev-profile-base" ]; then
        PROFILE_DIR="$DEV_PROFILES_DIR/dev-profile-base"
        print_info "Using dev-profile-base subdirectory"
    else
        PROFILE_DIR="$DEV_PROFILES_DIR"
        print_info "Using developer-profiles directory directly"
    fi
    
    PROFILE_ENV="$PROFILE_DIR/.env"
    OVERRIDES_ENV="$PROFILE_DIR/overrides.env"
    VSS_DATA_DIR="$VSS_DIR/data"
    
    print_info "Profile directory: $PROFILE_DIR"
    print_info "Expected .env location: $PROFILE_ENV"
    
    # List files in the profile directory for debugging
    print_info "Files in profile directory:"
    ls -la "$PROFILE_DIR" 2>/dev/null || print_warning "Cannot list directory contents"

    # Set VSS_AGENT_CONFIG_FILE to container path (not host path)
    # The VSS agent expects the config file to be at a specific location in the container
    print_info "Setting VSS_AGENT_CONFIG_FILE to container path"
    VSS_AGENT_CONFIG_FILE="/vss-agent/deploy/docker/developer-profiles/dev-profile-base/vss-agent/configs/config.yml"

    # Configure dev-profile-base .env
    if [ -f "$PROFILE_ENV" ]; then
        cp "$PROFILE_ENV" "${PROFILE_ENV}.backup"
        
        # Set VSS_AGENT_CONFIG_FILE to container path
        if grep -q "^VSS_AGENT_CONFIG_FILE=" "$PROFILE_ENV"; then
            sed -i "s|^VSS_AGENT_CONFIG_FILE=.*|VSS_AGENT_CONFIG_FILE=/vss-agent/deploy/docker/developer-profiles/dev-profile-base/vss-agent/configs/config.yml|" "$PROFILE_ENV"
            print_info "Updated VSS_AGENT_CONFIG_FILE in .env to container path"
        else
            echo "VSS_AGENT_CONFIG_FILE=/vss-agent/deploy/docker/developer-profiles/dev-profile-base/vss-agent/configs/config.yml" >> "$PROFILE_ENV"
            print_info "Added VSS_AGENT_CONFIG_FILE to .env (container path)"
        fi
        
        # Update EVAL_DIR to use the correct path
        if grep -q "^EVAL_DIR=" "$PROFILE_ENV"; then
            sed -i "s|^EVAL_DIR=.*|EVAL_DIR=$PROFILE_DIR/eval/|" "$PROFILE_ENV"
            print_info "Updated EVAL_DIR in existing .env"
        fi
        
        # Update DATASET_DIR to use the correct path
        if grep -q "^DATASET_DIR=" "$PROFILE_ENV"; then
            sed -i "s|^DATASET_DIR=.*|DATASET_DIR=$PROFILE_DIR/agent_eval/dataset/vss-devx-base|" "$PROFILE_ENV"
            print_info "Updated DATASET_DIR in existing .env"
        fi
        
        # Update REPORT_REFERENCE_BASE_DIR to use the correct path
        if grep -q "^REPORT_REFERENCE_BASE_DIR=" "$PROFILE_ENV"; then
            sed -i "s|^REPORT_REFERENCE_BASE_DIR=.*|REPORT_REFERENCE_BASE_DIR=$PROFILE_DIR/agent_eval/dataset/vss-devx-base/gt|" "$PROFILE_ENV"
            print_info "Updated REPORT_REFERENCE_BASE_DIR in existing .env"
        fi
        
        # Update EVAL_OUTPUT_DIR to use the correct path
        if grep -q "^EVAL_OUTPUT_DIR=" "$PROFILE_ENV"; then
            sed -i "s|^EVAL_OUTPUT_DIR=.*|EVAL_OUTPUT_DIR=$PROFILE_DIR/agent_eval/results|" "$PROFILE_ENV"
            print_info "Updated EVAL_OUTPUT_DIR in existing .env"
        fi
        
        # The .env file has static defaults, no user-specific variables needed
        print_success "Configured dev-profile-base/.env (using static defaults)"
    else
        print_warning ".env file not found at $PROFILE_ENV"
        print_info "Creating .env file from scratch..."
        
        # Create the .env file with required variables from official VSS Blueprint
        # Note: Use literal values so docker-compose can read them directly
        cat > "$PROFILE_ENV" << EOF
MODE=2d
RTVI_VLM_MAX_MODEL_LEN=''
BP_PROFILE=bp_developer_base
RESERVED_DEVICE_IDS=''
FIXED_SHARED_DEVICE_IDS=''
ELASTICSEARCH_ILM_MIN_AGE=4h
STREAM_TYPE=kafka
VSS_AGENT_CONFIG_FILE=/vss-agent/deploy/docker/developer-profiles/dev-profile-base/vss-agent/configs/config.yml
ENABLE_AUDIO=false
NEXT_PUBLIC_APP_SUBTITLE="Vision (Base)"
NEXT_PUBLIC_SIDEBAR_CHAT_WORKFLOW="VSS Agent"
NEXT_PUBLIC_SIDEBAR_CHAT_CHAT_API_CUSTOM_AGENT_PARAMS_JSON={"params":[{"name":"llm_reasoning","label":"LLM Reasoning","type":"boolean","default-value":true,"changeable":true,"tooltip-info":"Improves tool-call planning and QA accuracy; adds latency on multi-turn conversations. Turn off for fastest multi-turn replies."},{"name":"vlm_reasoning","label":"VLM Reasoning","type":"boolean","default-value":false,"changeable":true,"tooltip-info":""}]}
NEXT_PUBLIC_SIDEBAR_CHAT_CHAT_UPLOAD_FILE_ENABLE=true
NEXT_PUBLIC_SIDEBAR_CHAT_WEB_SOCKET_DEFAULT_ON=true
NEXT_PUBLIC_ENABLE_ALERTS_TAB=false
NEXT_PUBLIC_ENABLE_SEARCH_TAB=false
NEXT_PUBLIC_ENABLE_DASHBOARD_TAB=false
NEXT_PUBLIC_ENABLE_VIDEO_MANAGEMENT_TAB=true
NEXT_PUBLIC_VIDEO_MANAGEMENT_VIDEO_UPLOAD_ENABLE=true
NEXT_PUBLIC_VIDEO_MANAGEMENT_TAB_ADD_RTSP_ENABLE=false
EVAL_DIR=$PROFILE_DIR/eval/
DATASET_DIR=$PROFILE_DIR/agent_eval/dataset/vss-devx-base
DATASET_FILE_NAME=dataset_single-turn.json
REPORT_REFERENCE_BASE_DIR=$PROFILE_DIR/agent_eval/dataset/vss-devx-base/gt
EVAL_OUTPUT_DIR=$PROFILE_DIR/agent_eval/results
EOF
        
        print_success "Created .env file at $PROFILE_ENV"
        
        # Show the contents for debugging
        print_info "Contents of created .env file:"
        cat "$PROFILE_ENV"
    fi

    # Configure overrides.env
    if [ -f "$OVERRIDES_ENV" ]; then
        cp "$OVERRIDES_ENV" "${OVERRIDES_ENV}.backup"
        
        # Update the key user-specific variables
        sed -i "s#VSS_APPS_DIR=\"/path/to/deploy/docker\"#VSS_APPS_DIR=\"$VSS_APPS_DIR\"#" "$OVERRIDES_ENV"
        sed -i "s#VSS_DATA_DIR=\"/path/to/vss-apps-data\"#VSS_DATA_DIR=\"$VSS_DIR/data\"#" "$OVERRIDES_ENV"
        sed -i "s#HOST_IP='<HOST_IP>'#HOST_IP='$HOST_IP'#" "$OVERRIDES_ENV"
        sed -i "s#EXTERNAL_IP=\${HOST_IP}#EXTERNAL_IP=$HOST_IP#" "$OVERRIDES_ENV"
        sed -i "s#NGC_CLI_API_KEY=\${NGC_CLI_API_KEY:-}#NGC_CLI_API_KEY=$NGC_API_KEY#" "$OVERRIDES_ENV"
        sed -i "s#NVIDIA_API_KEY=\${NVIDIA_API_KEY:-}#NVIDIA_API_KEY=$NGC_API_KEY#" "$OVERRIDES_ENV"
        sed -i "s#HARDWARE_PROFILE=H100#HARDWARE_PROFILE=RTXPRO6000BW#" "$OVERRIDES_ENV"
        sed -i "s#LLM_DEVICE_ID='0'#LLM_DEVICE_ID='1'#" "$OVERRIDES_ENV"
        sed -i "s#VSS_PUBLIC_HOST=\${EXTERNAL_IP}#VSS_PUBLIC_HOST=$HOST_IP#" "$OVERRIDES_ENV"
        sed -i "s#VST_EXTERNAL_URL=\${VSS_PUBLIC_HTTP_PROTOCOL}://\${VSS_PUBLIC_HOST}:\${VSS_PUBLIC_PORT}#VST_EXTERNAL_URL=http://$HOST_IP:7777#" "$OVERRIDES_ENV"
        sed -i "s#VST_BASE_URL=\${VST_EXTERNAL_URL}#VST_BASE_URL=http://$HOST_IP:7777#" "$OVERRIDES_ENV"
        sed -i "s#VSS_AGENT_REPORTS_BASE_URL=\${VSS_PUBLIC_HTTP_PROTOCOL}://\${VSS_PUBLIC_HOST}:\${VSS_PUBLIC_PORT}/static/#VSS_AGENT_REPORTS_BASE_URL=http://$HOST_IP:7777/static/#" "$OVERRIDES_ENV"
        sed -i "s#VSS_AGENT_EXTERNAL_URL=\${VSS_PUBLIC_HTTP_PROTOCOL}://\${VSS_PUBLIC_HOST}:\${VSS_PUBLIC_PORT}#VSS_AGENT_EXTERNAL_URL=http://$HOST_IP:7777#" "$OVERRIDES_ENV"
        
        # Set VSS_AGENT_CONFIG_FILE to container path
        if grep -q "^VSS_AGENT_CONFIG_FILE=" "$OVERRIDES_ENV"; then
            sed -i "s|^VSS_AGENT_CONFIG_FILE=.*|VSS_AGENT_CONFIG_FILE=/vss-agent/deploy/docker/developer-profiles/dev-profile-base/vss-agent/configs/config.yml|" "$OVERRIDES_ENV"
            print_info "Updated VSS_AGENT_CONFIG_FILE in overrides.env to container path"
        else
            echo "VSS_AGENT_CONFIG_FILE=/vss-agent/deploy/docker/developer-profiles/dev-profile-base/vss-agent/configs/config.yml" >> "$OVERRIDES_ENV"
            print_info "Added VSS_AGENT_CONFIG_FILE to overrides.env (container path)"
        fi
        
        # Add tmp directory variables to overrides.env
        if ! grep -q "^TMPDIR=" "$OVERRIDES_ENV"; then
            echo "TMPDIR=/tmp" >> "$OVERRIDES_ENV"
            echo "TEMP=/tmp" >> "$OVERRIDES_ENV"
            echo "TMP=/tmp" >> "$OVERRIDES_ENV"
            echo "XDG_RUNTIME_DIR=/tmp" >> "$OVERRIDES_ENV"
            print_info "Added tmp directory variables to overrides.env"
        fi
        
        print_success "Configured overrides.env"
    else
        print_warning "overrides.env not found at $OVERRIDES_ENV"
        print_info "Creating overrides.env from scratch..."
        
        # Create the overrides.env file with required variables from official VSS Blueprint
        cat > "$OVERRIDES_ENV" << EOF
COMPOSE_PROJECT_NAME=vss
HARDWARE_PROFILE=RTXPRO6000BW
LLM_DEVICE_ID='1'
VLM_DEVICE_ID='0'
RT_VLM_DEVICE_ID='0'
LLM_MODE=local_shared
VLM_MODE=local_shared
LLM_NAME=nvidia/nemotron-3.5-lightning-30b-a3b
LLM_NAME_SLUG=nemotron-3.5-lightning-30b-a3b
LLM_ENV_FILE=''
LLM_BASE_URL=http://vss-llm-nim:8000
LLM_MODEL_TYPE=nim
VLM_NAME=nim_nvidia_cosmos3-nano-reasoner_bf16-final
VLM_NAME_SLUG=none
VLM_ENV_FILE=''
VLM_BASE_URL=http://rtvi-vlm:8000
VLM_MODEL_TYPE=rtvi
VLM_PORT=8018
VSS_APPS_DIR=$VSS_APPS_DIR
VSS_DATA_DIR=$VSS_DIR/data
HOST_IP='$HOST_IP'
EXTERNAL_IP=$HOST_IP
VSS_AGENT_CONFIG_FILE=/vss-agent/deploy/docker/developer-profiles/dev-profile-base/vss-agent/configs/config.yml
HAPROXY_PORT=7777
VSS_PUBLIC_HTTP_PROTOCOL=http
VSS_PUBLIC_WS_PROTOCOL=ws
VSS_PUBLIC_HOST=$HOST_IP
HAPROXY_HOST_PORT=7777
VSS_PUBLIC_PORT=7777
VSS_UI_HOST_PORT=3000
VSS_AGENT_HOST_PORT=8000
RTVI_VLM_PORT=8018
PHOENIX_HOST_PORT=6006
REDIS_HOST_PORT=6379
VST_INGRESS_HOST_PORT=30888
SENSOR_HTTP_HOST_PORT=30000
STREAM_PROCESSOR_HTTP_HOST_PORT=30001
RTSP_SERVER_HOST_PORT=30554
RTSP_SERVER_HOST_PORT_END=30564
VST_CONFIG_PATH=$VSS_APPS_DIR/services/vios/configs
VST_EXTERNAL_URL=http://$HOST_IP:7777
VST_BASE_URL=http://$HOST_IP:7777
VSS_AGENT_REPORTS_BASE_URL=http://$HOST_IP:7777/static/
VSS_AGENT_EXTERNAL_URL=http://$HOST_IP:7777
VSS_AGENT_ADAPTER_ENABLED=false
HITL_ENABLED=true
NGC_CLI_API_KEY=$NGC_API_KEY
NVIDIA_API_KEY=$NGC_API_KEY
OPENAI_API_KEY=
HF_TOKEN=
EVAL_LLM_JUDGE_NAME=nvidia/nemotron-3.5-lightning-30b-a3b
EVAL_LLM_JUDGE_BASE_URL=http://vss-llm-nim:8000
RTVI_VLM_ENDPOINT=''
RTVI_VLM_MODEL_TO_USE=cosmos-reason3
RTVI_VLLM_GPU_MEMORY_UTILIZATION=''
RTVI_VLLM_MM_PROCESSOR_CACHE_GB=0
EOF
        
        print_success "Created overrides.env at $OVERRIDES_ENV"
    fi

    # Update vss-sports-ui .env with correct VSS_APPS_DIR
    sed -i "s|^VSS_APPS_DIR=.*|VSS_APPS_DIR=$VSS_APPS_DIR|" "$SPORTS_UI_ENV"
    sed -i "s|^VSS_DATA_DIR=.*|VSS_DATA_DIR=$VSS_DIR/data|" "$SPORTS_UI_ENV"
    
    print_success "Updated vss-sports-ui/.env with correct paths"

    # Configure service .env files
    print_info "Configuring service .env files..."

    # Find services directory, preferring docker over helm
    SERVICES_DIR=$(find "$VSS_DIR/deploy/docker" -type d -name "services" 2>/dev/null | head -1)
    
    # If not found in docker, search anywhere but exclude helm
    if [ -z "$SERVICES_DIR" ]; then
        SERVICES_DIR=$(find "$VSS_DIR" -type d -name "services" 2>/dev/null | grep -v "/helm/" | head -1)
    fi
    
    if [ -z "$SERVICES_DIR" ]; then
        print_warning "Could not find services directory, skipping service .env configuration"
    else
        print_info "Found services directory at: $SERVICES_DIR"
        
        # List of env files to configure
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
            source_file="$SERVICES_DIR/$env_file"

            if [ -f "$source_file" ]; then
                # Add VSS_APPS_DIR if not already present
                if ! grep -q "^VSS_APPS_DIR=" "$source_file"; then
                    echo "VSS_APPS_DIR=$VSS_APPS_DIR" >> "$source_file"
                fi
                
                print_success "Configured $env_file"
            else
                print_warning "Skipping $env_file (not found at $source_file)"
            fi
        done
    fi

    print_success "All environment files configured"

    # Export VSS_APPS_DIR and PROFILE_ENV for use in other functions
    export VSS_APPS_DIR
    export PROFILE_ENV
    export OVERRIDES_ENV
    export VSS_DIR
    export VSS_DATA_DIR
    export VSS_AGENT_CONFIG_FILE

    # Print configuration summary
    print_info "Configuration paths:"
    print_info "  VSS_DIR: $VSS_DIR"
    print_info "  VSS_APPS_DIR: $VSS_APPS_DIR"
    print_info "  VSS_DATA_DIR: $VSS_DATA_DIR"
    print_info "  PROFILE_DIR: $PROFILE_DIR"
    print_info "  PROFILE_ENV: $PROFILE_ENV"
    print_info "  OVERRIDES_ENV: $OVERRIDES_ENV"
    print_info "  VSS_AGENT_CONFIG_FILE: $VSS_AGENT_CONFIG_FILE (container path)"
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

    # Fix Docker volume mounting issues
    print_info "Configuring Docker for proper volume mounting..."
    
    # Ensure Docker service is running
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Check if Docker data directory exists and has proper permissions
    DOCKER_DATA_DIR=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk '{print $3}')
    if [ -n "$DOCKER_DATA_DIR" ]; then
        print_info "Docker data directory: $DOCKER_DATA_DIR"
        
        # If Docker is using /mnt/docker, just warn but don't try to reconfigure
        if echo "$DOCKER_DATA_DIR" | grep -q "/mnt/docker"; then
            print_warning "Docker is using /mnt/docker (non-standard path)"
            print_info "This may cause issues but we won't reconfigure it automatically"
            print_info "If you encounter issues, you may need to manually reconfigure Docker"
        fi
    fi
    
    # Clean up any orphaned volumes that might cause issues
    print_info "Cleaning up orphaned Docker volumes..."
    docker volume prune -f 2>/dev/null || true
    
    print_success "Docker configuration complete"
}

install_dependencies() {
    print_header "Installing System Dependencies"

    print_warning "Skipping NVIDIA driver installation to preserve your existing setup"
    print_info "Your current NVIDIA drivers will be preserved"
    print_info "Blocking nvidia driver packages from apt"
    print_warning "Blocking kernel updates to preserve current kernel configuration"

    # Pin nvidia packages to prevent auto-installation
    sudo apt-mark hold nvidia-driver-* nvidia-* 2>/dev/null || true
    
    # Pin kernel packages to prevent kernel updates
    sudo apt-mark hold linux-image-* linux-headers-* linux-modules-* 2>/dev/null || true
    
    # Create apt preferences to block kernel and driver updates
    sudo tee /etc/apt/preferences.d/no-kernel-upgrade > /dev/null << 'EOF'
Package: linux-image-*
Pin: release *
Pin-Priority: -1

Package: linux-headers-*
Pin: release *
Pin-Priority: -1

Package: linux-modules-*
Pin: release *
Pin-Priority: -1

Package: nvidia-driver-*
Pin: release *
Pin-Priority: -1

Package: nvidia-*
Pin: release *
Pin-Priority: -1
EOF
    
    sudo apt-get update
    
    # Install dependencies without nvidia packages
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

    print_success "System dependencies installed (NVIDIA drivers and kernel preserved)"
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
}

deploy_vss_backend() {
    print_header "Deploying VSS Backend"

    cd "$INSTALL_DIR/video-search-and-summarization/deploy/docker"

    # Clean up any existing VSS volumes to prevent mounting errors
    print_info "Cleaning up existing VSS Docker volumes..."
    docker volume rm vss_agent-eval 2>/dev/null || true
    docker volume rm vss_agent_data 2>/dev/null || true
    docker volume rm vss_vlm_data 2>/dev/null || true
    docker volume rm vss_llm_data 2>/dev/null || true
    docker volume rm vss_rtvi_data 2>/dev/null || true
    docker volume rm vss_elasticsearch_data 2>/dev/null || true
    docker volume rm vss_kafka_data 2>/dev/null || true
    docker volume rm vss_zookeeper_data 2>/dev/null || true
    docker volume rm vss_redis_data 2>/dev/null || true
    docker volume rm vss_postgres_data 2>/dev/null || true
    print_success "Cleaned up existing volumes"
    
    # Fix permissions on /mnt/docker if it exists (even if not used by Docker)
    if [ -d "/mnt/docker" ]; then
        print_warning "Found /mnt/docker directory, fixing permissions..."
        sudo chmod -R 755 /mnt/docker 2>/dev/null || print_warning "Could not chmod /mnt/docker (may be OK)"
        sudo chown -R root:root /mnt/docker 2>/dev/null || print_warning "Could not chown /mnt/docker (may be OK)"
        print_success "Attempted to fix permissions on /mnt/docker"
    fi
    
    # Create .env file in deploy/docker directory for docker-compose
    print_info "Creating .env file in deploy/docker directory..."
    cat > .env << EOF
VSS_APPS_DIR=$VSS_APPS_DIR
VSS_DATA_DIR=$VSS_DATA_DIR
HOST_IP=$HOST_IP
VSS_AGENT_CONFIG_FILE=/vss-agent/deploy/docker/developer-profiles/dev-profile-base/vss-agent/configs/config.yml
TMPDIR=/tmp
TEMP=/tmp
TMP=/tmp
XDG_RUNTIME_DIR=/tmp
EOF
    print_success "Created .env file in deploy/docker directory"
    print_info "Contents:"
    cat .env
    
    # Ensure tmp directory exists and is writable
    print_info "Ensuring tmp directory exists..."
    mkdir -p /tmp /var/tmp /usr/tmp
    chmod 777 /tmp /var/tmp /usr/tmp
    print_success "Tmp directory is ready"
    
    # VSS Blueprint will handle config file path internally
    
    # VSS Blueprint will handle config file path internally
    
    # Create local directories for data storage (as fallback for volume mounting issues)
    print_info "Creating local data directories as fallback..."
    mkdir -p "$VSS_DATA_DIR/agent/eval"
    mkdir -p "$VSS_DATA_DIR/agent/data"
    mkdir -p "$VSS_DATA_DIR/vlm/data"
    mkdir -p "$VSS_DATA_DIR/llm/data"
    mkdir -p "$VSS_DATA_DIR/rtvi/data"
    mkdir -p "$VSS_DATA_DIR/elasticsearch/data"
    mkdir -p "$VSS_DATA_DIR/kafka/data"
    mkdir -p "$VSS_DATA_DIR/zookeeper/data"
    mkdir -p "$VSS_DATA_DIR/redis/data"
    mkdir -p "$VSS_DATA_DIR/postgres/data"
    print_success "Created local data directories"

    # Export VSS_APPS_DIR for Docker Compose (use the dynamically discovered path)
    export VSS_APPS_DIR="$VSS_APPS_DIR"
    export VSS_DATA_DIR="$VSS_DIR/data"
    export HOST_IP="$HOST_IP"
    export NGC_CLI_API_KEY="$NGC_API_KEY"
    export NVIDIA_API_KEY="$NGC_API_KEY"
    export HARDWARE_PROFILE="RTXPRO6000BW"
    export LLM_MODE="local_shared"
    export VLM_MODE="local_shared"
    export LLM_DEVICE_ID='1'  # Use GPU 1 for 30b model (more resources)
    export VLM_DEVICE_ID='0'  # Use GPU 0 for VLM
    export RT_VLM_DEVICE_ID='0'
    
    # Set tmp directory for containers
    export TMPDIR=/tmp
    export TEMP=/tmp
    export TMP=/tmp
    export XDG_RUNTIME_DIR=/tmp
    
    # Explicitly prevent driver installation
    export SKIP_DRIVER_INSTALL=true
    export NVIDIA_DRIVER_INSTALL=false
    export DISABLE_NVIDIA_DRIVER_UPDATE=true
    export NVIDIA_SILENT=true
    export CUDA_DRIVER_AUTO_UPDATE=false
    export ACCEPT_EULA=Y
    
    # Prevent kernel updates
    export SKIP_KERNEL_UPDATE=true
    export DISABLE_KERNEL_UPDATE=true
    
    # Add nvidia-smi to PATH to prevent auto-update
    export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
    
    # Create a marker file to prevent driver and kernel updates
    touch /tmp/.skip_nvidia_driver_update
    touch /tmp/.skip_kernel_update
    
    # Validate VSS_APPS_DIR is set
    if [ -z "$VSS_APPS_DIR" ]; then
        print_error "VSS_APPS_DIR is not set before docker-compose"
        print_info "This should have been set in configure_all_env_files"
        exit 1
    fi
    
    print_info "Setting VSS_APPS_DIR=$VSS_APPS_DIR"
    print_info "Setting VSS_DATA_DIR=$VSS_DATA_DIR"
    print_info "Setting HOST_IP=$HOST_IP"
    print_info "Setting HARDWARE_PROFILE=RTXPRO6000BW"
    print_warning "Skipping NVIDIA driver installation (preserving version 580.105.08)"

    print_info "Starting VSS services with Docker Compose..."
    print_warning "This may take 10-20 minutes on first run (downloading Docker images)"

    # Verify the .env file exists before starting
    if [ ! -f "$PROFILE_ENV" ]; then
        print_error ".env file not found at $PROFILE_ENV"
        print_info "This should have been created during configuration"
        exit 1
    fi

    # Verify overrides.env exists
    if [ ! -f "$OVERRIDES_ENV" ]; then
        print_error "overrides.env file not found at $OVERRIDES_ENV"
        print_info "This should have been created during configuration"
        exit 1
    fi

    print_info "Using .env file: $PROFILE_ENV"
    print_info "Using overrides.env file: $OVERRIDES_ENV"
    print_info "VSS_APPS_DIR: $VSS_APPS_DIR"
    print_info "VSS_DATA_DIR: $VSS_DATA_DIR"

    # Verify docker-compose configuration
    print_info "Verifying docker-compose configuration..."
    if docker-compose config > /tmp/vss-compose-resolved.yml 2>&1; then
        print_success "Docker-compose configuration is valid"
    else
        print_error "Docker-compose configuration is invalid"
        print_info "Check /tmp/vss-compose-resolved.yml for details"
        cat /tmp/vss-compose-resolved.yml
        exit 1
    fi

    # Start the services - load both .env files (overrides.env takes precedence)
    docker-compose -f compose.yml --env-file "$PROFILE_ENV" --env-file "$OVERRIDES_ENV" up -d

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

    # Verify driver and kernel versions haven't changed
    print_info "Verifying driver and kernel versions..."
    if [ -n "$CURRENT_DRIVER_VERSION" ]; then
        CURRENT_DRIVER_AFTER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
        if [ "$CURRENT_DRIVER_VERSION" != "$CURRENT_DRIVER_AFTER" ]; then
            print_error "NVIDIA driver version changed!"
            print_info "Before: $CURRENT_DRIVER_VERSION"
            print_info "After: $CURRENT_DRIVER_AFTER"
            print_warning "This should not have happened. Please investigate."
        else
            print_success "NVIDIA driver version unchanged: $CURRENT_DRIVER_VERSION"
        fi
    fi

    if [ -n "$CURRENT_KERNEL_VERSION" ]; then
        CURRENT_KERNEL_AFTER=$(uname -r)
        if [ "$CURRENT_KERNEL_VERSION" != "$CURRENT_KERNEL_AFTER" ]; then
            print_error "Kernel version changed!"
            print_info "Before: $CURRENT_KERNEL_VERSION"
            print_info "After: $CURRENT_KERNEL_AFTER"
            print_warning "This should not have happened. Please investigate."
        else
            print_success "Kernel version unchanged: $CURRENT_KERNEL_VERSION"
        fi
    fi

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
    echo -e "${BLUE}System Configuration Preserved:${NC}"
    echo -e "  NVIDIA Driver: $CURRENT_DRIVER_VERSION"
    echo -e "  Kernel: $CURRENT_KERNEL_VERSION"
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
    echo ""
    echo -e "${YELLOW}IMPORTANT: NVIDIA drivers and kernel were NOT modified during installation${NC}"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    print_header "VSS Sports Analysis - Installation Script"

    print_warning "IMPORTANT: This script will NOT install or modify NVIDIA drivers"
    print_info "Your existing NVIDIA drivers will be preserved"
    print_info "If you need to install drivers, do so manually before running this script"
    print_info "Current driver version will be preserved (e.g., 580.105.08)"
    print_warning "IMPORTANT: This script will NOT update the kernel"
    print_info "Your current kernel configuration will be preserved"
    echo ""

    # Export global variables to prevent driver installation
    export SKIP_DRIVER_INSTALL=true
    export NVIDIA_DRIVER_INSTALL=false
    export DISABLE_NVIDIA_DRIVER_UPDATE=true
    export NVIDIA_SILENT=true
    
    # Prevent kernel updates
    export SKIP_KERNEL_UPDATE=true
    export DISABLE_KERNEL_UPDATE=true
    
    # Add nvidia-smi to PATH to prevent auto-update
    export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
    
    # Create a marker file to prevent driver and kernel updates
    touch /tmp/.skip_nvidia_driver_update
    touch /tmp/.skip_kernel_update

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

    # Step 4: Clone VSS Blueprint (must be done before configuring env files)
    setup_vss_blueprint

    # Step 5: Prompt for API keys
    prompt_api_keys

    # Step 6: Detect host IP
    detect_host_ip

    # Step 7: Configure all .env files (now VSS Blueprint is cloned)
    configure_all_env_files

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
