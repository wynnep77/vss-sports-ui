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
SERVICES_DIR="$VSS_DIR/deploy/docker/services"
VSS_APPS_DIR="$VSS_DIR/deploy/docker"
VSS_DATA_DIR="$VSS_DIR/data"

# Find the actual location of deployment templates
print_info "Searching for deployment templates..."

PROFILE_DIR=""
OVERRIDES_ENV=""
CONTAINERS_ENV=""

# Search for dev-profile-base directory
if [ -d "$VSS_DIR/deploy/docker/developer-profiles/dev-profile-base" ]; then
    PROFILE_DIR="$VSS_DIR/deploy/docker/developer-profiles/dev-profile-base"
elif [ -d "$VSS_DIR/deploy/docker/developer-profiles" ]; then
    PROFILE_DIR="$VSS_DIR/deploy/docker/developer-profiles"
else
    print_error "Could not find developer-profiles directory"
    print_info "Searched in: $VSS_DIR/deploy/docker"
    exit 1
fi

# Set paths based on found directory
PROFILE_ENV="$PROFILE_DIR/.env"
OVERRIDES_ENV="$PROFILE_DIR/overrides.env"
CONTAINERS_ENV="$VSS_DIR/deploy/docker/containers.env"

print_info "Found deployment templates in: $PROFILE_DIR"

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
PROFILE_ENV="$VSS_DIR/deploy/docker/developer-profiles/dev-profile-base/.env"

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
fi

# Configure overrides.env
print_header "Configuring overrides.env"
OVERRIDES_ENV="$VSS_DIR/deploy/docker/developer-profiles/dev-profile-base/overrides.env"

if [ -f "$OVERRIDES_ENV" ]; then
    cp "$OVERRIDES_ENV" "${OVERRIDES_ENV}.backup"
    
    sed -i "s|VSS_APPS_DIR=\"/path/to/deploy/docker\"|VSS_APPS_DIR=\"$VSS_APPS_DIR\"|" "$OVERRIDES_ENV"
    sed -i "s|VSS_DATA_DIR=\"/path/to/vss-apps-data\"|VSS_DATA_DIR=\"$VSS_DATA_DIR\"|" "$OVERRIDES_ENV"
    sed -i "s|HOST_IP='<HOST_IP>'|HOST_IP='$HOST_IP'|" "$OVERRIDES_ENV"
    sed -i "s|EXTERNAL_IP=\${HOST_IP}|EXTERNAL_IP=$HOST_IP|" "$OVERRIDES_ENV"
    sed -i "s|NGC_CLI_API_KEY=\${NGC_CLI_API_KEY:-}|NGC_CLI_API_KEY=$NGC_API_KEY|" "$OVERRIDES_ENV"
    sed -i "s|NVIDIA_API_KEY=\${NVIDIA_API_KEY:-}|NVIDIA_API_KEY=$NGC_API_KEY|" "$OVERRIDES_ENV"
    sed -i "s|HARDWARE_PROFILE=H100|HARDWARE_PROFILE=RTXPRO6000BW|" "$OVERRIDES_ENV"
    
    # Set LLM and VLM modes
    sed -i "s|LLM_MODE=local_shared|LLM_MODE=local_shared|" "$OVERRIDES_ENV"
    sed -i "s|VLM_MODE=local_shared|VLM_MODE=local_shared|" "$OVERRIDES_ENV"
    
    # Set device IDs
    sed -i "s|LLM_DEVICE_ID='0'|LLM_DEVICE_ID='0'|" "$OVERRIDES_ENV"
    sed -i "s|VLM_DEVICE_ID='0'|VLM_DEVICE_ID='0'|" "$OVERRIDES_ENV"
    sed -i "s|RT_VLM_DEVICE_ID='0'|RT_VLM_DEVICE_ID='0'|" "$OVERRIDES_ENV"
    
    print_success "Configured overrides.env"
else
    print_error "overrides.env not found"
fi

# Copy and configure service .env files
print_header "Configuring service .env files"

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
    dest_file="$SERVICES_DIR/$env_file"

    if [ -f "$source_file" ]; then
        # Add VSS_APPS_DIR if not already present
        if ! grep -q "^VSS_APPS_DIR=" "$dest_file"; then
            echo "VSS_APPS_DIR=$VSS_APPS_DIR" >> "$dest_file"
        fi
        
        print_success "Configured $env_file"
    else
        print_warning "Skipping $env_file (not found)"
    fi
done

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
echo -e "  VSS Apps Directory: $VSS_APPS_DIR"
echo -e "  VSS Data Directory: $VSS_DATA_DIR"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review the configured .env files"
echo "  2. Run the installation: ./install.sh"
echo "  3. Monitor the deployment logs"
echo ""
echo -e "${YELLOW}Backup files created with .backup extension${NC}"
