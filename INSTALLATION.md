# Installation Guide

This guide provides step-by-step instructions for deploying the VSS Sports Analysis system on Ubuntu with RTX PRO 6000 GPU.

## Quick Start (Automated Installation)

We provide automated installation scripts for both Ubuntu and Windows:

### Ubuntu Installation

```bash
# Download the script
wget https://raw.githubusercontent.com/wynnep77/vss-sports-ui/main/install.sh
chmod +x install.sh

# Run the installation
./install.sh
```

The script will:
1. Check your GPU and NVIDIA drivers
2. Install Docker and Docker Compose
3. Prompt for your NVIDIA NGC API key
4. Detect your network configuration
5. Clone and configure the VSS Blueprint
6. Deploy the VSS backend services
7. Clone and deploy the Sports UI frontend
8. Verify the deployment

### Windows Installation

```powershell
# Download the script
# Download install.ps1 from the repository

# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the installation
.\install.ps1
```

## Manual Installation

If you prefer to install manually, follow these steps:

### Prerequisites

- Ubuntu 24.04 (or compatible)
- RTX PRO 6000 GPU (or compatible NVIDIA GPU)
- NVIDIA GPU drivers (595.58.03 or later)
- Docker Engine (28.3.3 or later)
- Docker Compose (v2.39.1 or later)
- NVIDIA Container Toolkit (1.17.8+)
- NGC CLI (4.10.0+)
- NVIDIA NGC API key

### Step 1: Install NVIDIA Drivers

```bash
# Check if drivers are installed
nvidia-smi

# If not, install them
sudo apt-get update
sudo apt-get install -y nvidia-driver-595
```

### Step 2: Install Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

### Step 3: Install NVIDIA Container Toolkit

```bash
# Add NVIDIA repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install toolkit
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Step 4: Get NVIDIA NGC API Key

1. Visit https://build.nvidia.com/ or https://org.ngc.nvidia.com/setup/api-keys
2. Generate an API key
3. Save it for the next step

### Step 5: Clone and Configure VSS Blueprint

```bash
# Clone the VSS Blueprint repository
git clone https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization.git
cd video-search-and-summarization
```

### Step 5.5: Create Environment Configuration

Create a `.env` file in your vss-sports-ui directory (or in the current directory if running from there):

```bash
# If you have vss-sports-ui cloned
cd ~/vss-deployment/vss-sports-ui

# Copy the template
cp .env.template .env

# Edit the .env file
nano .env
```

Update the following variables in `.env`:
```bash
HOST_IP=<your-server-ip>
NGC_API_KEY=<your-ngc-api-key>
VSS_APPS_DIR=/home/demouser/vss-deployment/video-search-and-summarization/services/ui
LLM_BASE_URL=http://${HOST_IP}:30081
VLM_BASE_URL=http://${HOST_IP}:30082
VST_INTERNAL_URL=http://${HOST_IP}:30888
VST_EXTERNAL_URL=http://${HOST_IP}:30888
```

**Important**: The `.env` file should be located in the `vss-sports-ui` directory. The installation script will automatically copy it to the VSS Blueprint location.

### Step 6: Deploy VSS Backend

```bash
# Start the VSS services
docker-compose -f compose.yml --env-file .env up -d

# Monitor the logs
docker-compose logs -f

# Wait for services to be ready (may take 10-20 minutes on first run)
# Check health
curl http://localhost:8000/health
```

### Step 7: Deploy Sports UI Frontend

```bash
# Clone the Sports UI repository
git clone https://github.com/wynnep77/vss-sports-ui.git
cd vss-sports-ui

# Build the Docker image
docker build -t vss-sports-ui:latest .

# Run the container
docker run -d \
  --name vss-sports-ui \
  -p 80:80 \
  -e VITE_API_BASE_URL=http://<your-host-ip>:8000 \
  --add-host=host.docker.internal:host-gateway \
  --restart unless-stopped \
  vss-sports-ui:latest
```

### Step 8: Access the UI

Open your browser and navigate to:
- `http://<your-server-ip>` for the Sports UI
- `http://<your-server-ip>:8000` for the VSS agent API

## Troubleshooting

### GPU Not Detected

```bash
# Check NVIDIA driver
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

### Services Not Starting

```bash
# Check Docker logs
docker-compose logs

# Check specific service
docker-compose logs vss-agent
docker-compose logs vlm
docker-compose logs llm
```

### Port Conflicts

If ports are already in use, modify the `.env` file to use different ports:
```bash
LLM_PORT=30081
VLM_PORT=30082
VST_PORT=30888
VSS_AGENT_PORT=8000
```

### Out of Memory

If you encounter GPU memory issues:
1. Check GPU usage: `nvidia-smi`
2. Reduce batch sizes in the VSS configuration
3. Close other GPU-intensive applications

### Network Issues

If the UI can't connect to the VSS agent:
1. Verify the VSS agent is running: `curl http://localhost:8000/health`
2. Check firewall settings
3. Verify `VITE_API_BASE_URL` is correct
4. Check nginx proxy configuration

## Performance Optimization

### GPU Optimization

```bash
# Set GPU performance mode
sudo nvidia-smi -pm 1
sudo nvidia-smi -pl 250  # Set power limit (adjust for your GPU)
```

### Docker Optimization

Edit `/etc/docker/daemon.json`:
```json
{
  "default-runtime": "nvidia",
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Restart Docker:
```bash
sudo systemctl restart docker
```

## Updating the System

### Update VSS Blueprint

```bash
cd ~/vss-deployment/video-search-and-summarization
git pull
cd deploy/docker
docker-compose -f compose.yml --env-file .env up -d --force-recreate
```

### Update Sports UI

```bash
cd ~/vss-deployment/vss-sports-ui
git pull
docker build -t vss-sports-ui:latest .
docker stop vss-sports-ui
docker rm vss-sports-ui
docker run -d \
  --name vss-sports-ui \
  -p 80:80 \
  -e VITE_API_BASE_URL=http://<your-host-ip>:8000 \
  --add-host=host.docker.internal:host-gateway \
  --restart unless-stopped \
  vss-sports-ui:latest
```

## Uninstallation

### Stop All Services

```bash
# Stop VSS backend
cd ~/vss-deployment/video-search-and-summarization/deploy/docker
docker-compose -f compose.yml down

# Stop Sports UI
docker stop vss-sports-ui
docker rm vss-sports-ui

# Remove Docker images (optional)
docker rmi vss-sports-ui:latest
```

### Remove Files

```bash
# Remove deployment directory
rm -rf ~/vss-deployment
```

## Support

For issues related to:
- **VSS Blueprint**: https://docs.nvidia.com/vss/latest/index.html
- **Sports UI**: https://github.com/wynnep77/vss-sports-ui/issues
- **NVIDIA GPUs**: https://developer.nvidia.com/
