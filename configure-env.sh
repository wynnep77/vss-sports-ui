#!/bin/bash

################################################################################
# VSS Environment Configuration Script
# This script populates all .env files with valid configuration values
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Configuration variables
INSTALL_DIR="$HOME/vss-deployment"
HOST_IP=""
NGC_API_KEY=""

# Detect directories
CURRENT_DIR="$(pwd)"
if [ "$(basename $CURRENT_DIR)" = "vss-sports-ui" ]; then
    INSTALL_DIR="$(dirname $CURRENT_DIR)"
fi

VSS_DIR="$INSTALL_DIR/video-search-and-summarization"

# Check if VSS Blueprint exists
if [ ! -d "$VSS_DIR" ]; then
    print_error "VSS Blueprint not found at: $VSS_DIR"
    print_info "Please clone the VSS Blueprint first:"
    print_info "  cd $INSTALL_DIR"
    print_info "  git clone https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization.git"
    print_info ""
    print_info "Or run the main install.sh script which will clone it automatically"
    exit 1
fi

# Find the actual location of deployment templates
print_info "Searching for deployment templates..."

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

# Set paths based on found directory
PROFILE_ENV="$PROFILE_DIR/.env"
OVERRIDES_ENV="$PROFILE_DIR/overrides.env"
CONTAINERS_ENV="$VSS_DIR/deploy/docker/containers.env"

print_info "Profile directory: $PROFILE_DIR"
print_info "Expected .env location: $PROFILE_ENV"

# List files in the profile directory for debugging
print_info "Files in profile directory:"
ls -la "$PROFILE_DIR" 2>/dev/null || print_warning "Cannot list directory contents"

# Find services directory, preferring docker over helm
SERVICES_DIR=$(find "$VSS_DIR/deploy/docker" -type d -name "services" 2>/dev/null | head -1)

# If not found in docker, search anywhere but exclude helm
if [ -z "$SERVICES_DIR" ]; then
    SERVICES_DIR=$(find "$VSS_DIR" -type d -name "services" 2>/dev/null | grep -v "/helm/" | head -1)
fi

if [ -z "$SERVICES_DIR" ]; then
    print_warning "Could not find services directory"
else
    print_info "Found services directory at: $SERVICES_DIR"
fi

# Set data directory
VSS_DATA_DIR="$VSS_DIR/data"

print_info "Configuration paths:"
print_info "  VSS_DIR: $VSS_DIR"
print_info "  VSS_APPS_DIR: $VSS_APPS_DIR"
print_info "  VSS_DATA_DIR: $VSS_DATA_DIR"
print_info "  PROFILE_DIR: $PROFILE_DIR"
print_info "  SERVICES_DIR: $SERVICES_DIR"

# Get user input
print_header "VSS Environment Configuration"

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

# Get configuration
prompt_input "Server IP address" HOST_IP "$(hostname -I | awk '{print $1}')"
prompt_password "NVIDIA NGC API Key" NGC_API_KEY

print_info "Configuration:"
print_info "  Host IP: $HOST_IP"
print_info "  VSS Directory: $VSS_DIR"
print_info "  VSS Apps Directory: $VSS_APPS_DIR"
print_info "  VSS Data Directory: $VSS_DATA_DIR"
echo ""

# Configure dev-profile-base .env
print_header "Configuring dev-profile-base/.env"

# Use the PROFILE_ENV that was set earlier
if [ -f "$PROFILE_ENV" ]; then
    cp "$PROFILE_ENV" "${PROFILE_ENV}.backup"
    
    # The .env file has static defaults, no user-specific variables needed
    print_success "Configured dev-profile-base/.env (using static defaults)"
else
    print_warning ".env file not found at $PROFILE_ENV"
    print_info "Creating .env file from scratch..."
    
    # Create the .env file with required variables from official VSS Blueprint
    # Note: Use literal values so docker-compose can read them directly
    cat > "$PROFILE_ENV" << 'EOF'
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
EVAL_DIR=deploy/docker/developer-profiles/dev-profile-base/eval/
DATASET_DIR=agent_eval/dataset/vss-devx-base
DATASET_FILE_NAME=dataset_single-turn.json
REPORT_REFERENCE_BASE_DIR=/vss-agent/agent_eval/dataset/vss-devx-base/gt
EVAL_OUTPUT_DIR=agent_eval/results
EOF
    
    print_success "Created .env file at $PROFILE_ENV"
fi

# Configure overrides.env
print_header "Configuring overrides.env"

# Use the OVERRIDES_ENV that was set earlier
if [ -f "$OVERRIDES_ENV" ]; then
    cp "$OVERRIDES_ENV" "${OVERRIDES_ENV}.backup"
    
    # Update the key user-specific variables
    sed -i "s|VSS_APPS_DIR=\"/path/to/deploy/docker\"|VSS_APPS_DIR=\"$VSS_APPS_DIR\"|" "$OVERRIDES_ENV"
    sed -i "s|VSS_DATA_DIR=\"/path/to/vss-apps-data\"|VSS_DATA_DIR=\"$VSS_DATA_DIR\"|" "$OVERRIDES_ENV"
    sed -i "s|HOST_IP='<HOST_IP>'|HOST_IP='$HOST_IP'|" "$OVERRIDES_ENV"
    sed -i "s|EXTERNAL_IP=\${HOST_IP}|EXTERNAL_IP=$HOST_IP|" "$OVERRIDES_ENV"
    sed -i "s|NGC_CLI_API_KEY=\${NGC_CLI_API_KEY:-}|NGC_CLI_API_KEY=$NGC_API_KEY|" "$OVERRIDES_ENV"
    sed -i "s|NVIDIA_API_KEY=\${NVIDIA_API_KEY:-}|NVIDIA_API_KEY=$NGC_API_KEY|" "$OVERRIDES_ENV"
    sed -i "s|HARDWARE_PROFILE=H100|HARDWARE_PROFILE=RTXPRO6000BW|" "$OVERRIDES_ENV"
    sed -i "s|VSS_PUBLIC_HOST=\${EXTERNAL_IP}|VSS_PUBLIC_HOST=$HOST_IP|" "$OVERRIDES_ENV"
    sed -i "s|VST_EXTERNAL_URL=\${VSS_PUBLIC_HTTP_PROTOCOL}://\${VSS_PUBLIC_HOST}:\${VSS_PUBLIC_PORT}|VST_EXTERNAL_URL=http://$HOST_IP:7777|" "$OVERRIDES_ENV"
    sed -i "s|VST_BASE_URL=\${VST_EXTERNAL_URL}|VST_BASE_URL=http://$HOST_IP:7777|" "$OVERRIDES_ENV"
    sed -i "s|VSS_AGENT_REPORTS_BASE_URL=\${VSS_PUBLIC_HTTP_PROTOCOL}://\${VSS_PUBLIC_HOST}:\${VSS_PUBLIC_PORT}/static/|VSS_AGENT_REPORTS_BASE_URL=http://$HOST_IP:7777/static/|" "$OVERRIDES_ENV"
    sed -i "s|VSS_AGENT_EXTERNAL_URL=\${VSS_PUBLIC_HTTP_PROTOCOL}://\${VSS_PUBLIC_HOST}:\${VSS_PUBLIC_PORT}|VSS_AGENT_EXTERNAL_URL=http://$HOST_IP:7777|" "$OVERRIDES_ENV"
    
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
VSS_DATA_DIR=$VSS_DATA_DIR
HOST_IP='$HOST_IP'
EXTERNAL_IP=$HOST_IP
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

# Copy and configure service .env files
print_header "Configuring service .env files"

if [ -z "$SERVICES_DIR" ]; then
    print_warning "Services directory not found, skipping service .env configuration"
else
    # List of env files to configure (using a simple array instead of associative array)
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
            print_warning "Skipping $env_file (not found)"
        fi
    done
fi

# Create containers.env if it doesn't exist
print_header "Configuring containers.env"
CONTAINERS_ENV="$VSS_DIR/deploy/docker/containers.env"

if [ ! -f "$CONTAINERS_ENV" ]; then
    print_error "containers.env not found - this is required"
    exit 1
else
    print_success "containers.env exists (using defaults)"
fi

print_header "Configuration Complete!"

echo -e "${GREEN}Summary:${NC}"
echo -e "  Host IP: $HOST_IP"
echo -e "  VSS Directory: $VSS_DIR"
echo -e "  VSS Apps Directory: $VSS_APPS_DIR (contains developer-profiles)"
echo -e "  VSS Data Directory: $VSS_DATA_DIR"
echo -e "  Profile Directory: $PROFILE_DIR"
if [ -n "$SERVICES_DIR" ]; then
    echo -e "  Services Directory: $SERVICES_DIR"
fi
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review the configured .env files"
echo "  2. Run the installation: ./install.sh"
echo "  3. Monitor the deployment logs"
echo ""
echo -e "${YELLOW}Backup files created with .backup extension${NC}"
