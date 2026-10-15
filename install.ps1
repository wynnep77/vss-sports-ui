################################################################################
# VSS Sports Analysis - Complete Installation Script (PowerShell)
# This script installs the NVIDIA VSS Blueprint backend and the Sports UI frontend
# for Windows systems with RTX PRO 6000 GPU
################################################################################

# Error handling
$ErrorActionPreference = "Stop"

# Configuration variables
$INSTALL_DIR = "$HOME\vss-deployment"
$VSS_REPO = "https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization.git"
$FRONTEND_REPO = "https://github.com/wynnep77/vss-sports-ui.git"
$NGC_API_KEY = ""
$HOST_IP = ""

################################################################################
# Helper Functions
################################################################################

function Print-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Print-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Print-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Print-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Print-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-GPU {
    Print-Header "Checking GPU"

    if (Test-Command "nvidia-smi") {
        Print-Success "NVIDIA driver detected"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
        return $true
    } else {
        Print-Error "NVIDIA driver not found. Please install NVIDIA drivers first."
        Print-Info "Visit: https://www.nvidia.com/Download/index.aspx"
        return $false
    }
}

function Install-Docker {
    Print-Header "Installing Docker Desktop"

    if (Test-Command "docker") {
        Print-Success "Docker is already installed"
        docker --version
    } else {
        Print-Warning "Docker Desktop is not installed."
        Print-Info "Please download and install Docker Desktop for Windows from:"
        Print-Info "https://www.docker.com/products/docker-desktop"
        Print-Info "After installation, restart this script."
        Read-Host "Press Enter to exit"
        exit 1
    }

    if (Test-Command "docker-compose") {
        Print-Success "Docker Compose is already installed"
        docker-compose --version
    } else {
        Print-Warning "Docker Compose not found. It should be included with Docker Desktop."
    }
}

function Install-Dependencies {
    Print-Header "Installing System Dependencies"

    if (Test-Command "git") {
        Print-Success "Git is already installed"
        git --version
    } else {
        Print-Info "Git is required. Please install Git for Windows from:"
        Print-Info "https://git-scm.com/download/win"
        Read-Host "Press Enter to exit"
        exit 1
    }

    Print-Success "System dependencies check complete"
}

function Prompt-APIKeys {
    Print-Header "API Key Configuration"

    Print-Warning "You need an NVIDIA API key to use the NIM microservices."
    Print-Info "Get your API key from: https://build.nvidia.com/"
    Print-Info "Or from NGC: https://org.ngc.nvidia.com/setup/api-keys"

    $NGC_API_KEY = Read-Host "Enter your NVIDIA NGC API Key"

    if ([string]::IsNullOrWhiteSpace($NGC_API_KEY)) {
        Print-Error "API key is required. Please run the script again with a valid API key."
        exit 1
    }

    Print-Success "API key received"
    return $NGC_API_KEY
}

function Detect-HostIP {
    Print-Header "Network Configuration"

    # Try to detect the host IP automatically
    $ipconfig = ipconfig
    $HOST_IP = "127.0.0.1"

    if ($ipconfig -match "IPv4.*?(\d+\.\d+\.\d+\.\d+)") {
        $HOST_IP = $matches[1]
    }

    $userInput = Read-Host "Detected host IP [$HOST_IP]"
    if (-not [string]::IsNullOrWhiteSpace($userInput)) {
        $HOST_IP = $userInput
    }

    Print-Success "Using host IP: $HOST_IP"
    return $HOST_IP
}

function Setup-VSSBlueprint {
    param([string]$ApiKey, [string]$HostIP)

    Print-Header "Setting up NVIDIA VSS Blueprint"

    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }

    Set-Location $INSTALL_DIR

    $vssDir = Join-Path $INSTALL_DIR "video-search-and-summarization"

    if (Test-Path $vssDir) {
        Print-Warning "VSS Blueprint directory already exists. Pulling latest changes..."
        Set-Location $vssDir
        git pull
    } else {
        Print-Info "Cloning VSS Blueprint repository..."
        git clone $VSS_REPO
        Set-Location $vssDir
    }

    Print-Success "VSS Blueprint cloned"

    # Create environment file for dev-profile-base
    Print-Info "Configuring VSS environment..."

    $PROFILE_DIR = Join-Path $INSTALL_DIR "video-search-and-summarization\deploy\docker\developer-profiles\dev-profile-base"
    $ENV_FILE = Join-Path $PROFILE_DIR ".env"

    if (-not (Test-Path $ENV_FILE)) {
        Print-Error "Environment file not found at $ENV_FILE"
        Print-Info "Please ensure you're using a valid VSS Blueprint version"
        exit 1
    }

    # Backup original env file
    Copy-Item $ENV_FILE "$ENV_FILE.backup"

    # Read and update environment variables
    $envContent = Get-Content $ENV_FILE -Raw
    $envContent = $envContent -replace "HOST_IP=.*", "HOST_IP=$HostIP"
    $envContent = $envContent -replace "NGC_API_KEY=.*", "NGC_API_KEY=$ApiKey"

    # Set derived variables
    $LLM_PORT = "30081"
    $VLM_PORT = "30082"
    $VST_PORT = "30888"
    $VSS_APPS_DIR = Join-Path $INSTALL_DIR "video-search-and-summarization\services\ui"

    $envContent = $envContent -replace "LLM_BASE_URL=.*", "LLM_BASE_URL=http://`${HOST_IP}:$LLM_PORT"
    $envContent = $envContent -replace "VLM_BASE_URL=.*", "VLM_BASE_URL=http://`${HOST_IP}:$VLM_PORT"
    $envContent = $envContent -replace "VST_INTERNAL_URL=.*", "VST_INTERNAL_URL=http://`${HOST_IP}:$VST_PORT"
    $envContent = $envContent -replace "VST_EXTERNAL_URL=.*", "VST_EXTERNAL_URL=http://`${HOST_IP}:$VST_PORT"

    # Add VSS_APPS_DIR if not present
    if ($envContent -notmatch "VSS_APPS_DIR=") {
        $envContent += "`nVSS_APPS_DIR=$VSS_APPS_DIR"
    } else {
        $envContent = $envContent -replace "VSS_APPS_DIR=.*", "VSS_APPS_DIR=$VSS_APPS_DIR"
    }

    Set-Content $ENV_FILE $envContent

    Print-Success "VSS environment configured"
}

function Deploy-VSSBackend {
    Print-Header "Deploying VSS Backend"

    $deployDir = Join-Path $INSTALL_DIR "video-search-and-summarization\deploy\docker"
    Set-Location $deployDir

    Print-Info "Starting VSS services with Docker Compose..."
    Print-Warning "This may take 10-20 minutes on first run (downloading Docker images)"

    # Start the services
    $envFile = Join-Path $deployDir "..\developer-profiles\dev-profile-base\.env"
    docker-compose -f compose.yml --env-file $envFile up -d

    Print-Success "VSS backend services started"
    Print-Info "Waiting for services to be ready..."

    # Wait for services to be healthy
    $maxAttempts = 60
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Print-Success "VSS agent is ready!"
                break
            }
        } catch {
            # Continue waiting
        }

        $attempt++
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 5
    }

    if ($attempt -eq $maxAttempts) {
        Print-Error "VSS agent did not start within expected time"
        Print-Info "Check logs with: cd $deployDir && docker-compose logs"
        return $false
    }

    return $true
}

function Setup-SportsFrontend {
    Print-Header "Setting up Sports Analysis Frontend"

    Set-Location $INSTALL_DIR

    $uiDir = Join-Path $INSTALL_DIR "vss-sports-ui"

    if (Test-Path $uiDir) {
        Print-Warning "Sports UI directory already exists. Pulling latest changes..."
        Set-Location $uiDir
        git pull
    } else {
        Print-Info "Cloning Sports UI repository..."
        git clone $FRONTEND_REPO
        Set-Location $uiDir
    }

    Print-Success "Sports UI cloned"
}

function Deploy-SportsFrontend {
    param([string]$HostIP)

    Print-Header "Deploying Sports Analysis Frontend"

    $uiDir = Join-Path $INSTALL_DIR "vss-sports-ui"
    Set-Location $uiDir

    Print-Info "Building Docker image..."
    docker build -t vss-sports-ui:latest .

    Print-Info "Stopping existing container (if running)..."
    docker stop vss-sports-ui 2>$null
    docker rm vss-sports-ui 2>$null

    Print-Info "Starting Sports UI container..."
    docker run -d `
        --name vss-sports-ui `
        -p 80:80 `
        -e VITE_API_BASE_URL="http://$HostIP`:8000 `
        --add-host="host.docker.internal:host-gateway" `
        --restart unless-stopped `
        vss-sports-ui:latest

    Print-Success "Sports UI deployed on port 80"
}

function Verify-Deployment {
    Print-Header "Verifying Deployment"

    Print-Info "Checking VSS Agent..."
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Print-Success "VSS Agent is running on port 8000"
        }
    } catch {
        Print-Error "VSS Agent is not responding"
    }

    Print-Info "Checking Sports UI..."
    try {
        $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Print-Success "Sports UI is running on port 80"
        }
    } catch {
        Print-Error "Sports UI is not responding"
    }

    Print-Info "Checking Docker containers..."
    docker ps --filter "name=vss" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

function Print-Summary {
    param([string]$HostIP)

    Print-Header "Installation Complete!"

    Write-Host "✓ VSS Backend: http://$HostIP`:8000" -ForegroundColor Green
    Write-Host "✓ Sports UI: http://$HostIP" -ForegroundColor Green
    Write-Host ""
    Write-Host "Useful Commands:" -ForegroundColor Cyan
    Write-Host "  View VSS logs:    cd $INSTALL_DIR\video-search-and-summarization\deploy\docker && docker-compose logs -f"
    Write-Host "  View UI logs:      docker logs -f vss-sports-ui"
    Write-Host "  Stop VSS:         cd $INSTALL_DIR\video-search-and-summarization\deploy\docker && docker-compose down"
    Write-Host "  Stop UI:          docker stop vss-sports-ui"
    Write-Host "  Restart UI:       docker restart vss-sports-ui"
    Write-Host ""
    Write-Host "Note: First-time deployment may take additional time as models are downloaded." -ForegroundColor Yellow
    Write-Host "Monitor the VSS logs to see when models are fully loaded." -ForegroundColor Yellow
}

################################################################################
# Main Installation Flow
################################################################################

function Main {
    Print-Header "VSS Sports Analysis - Installation Script (Windows)"
    Write-Host "This script will install:"
    Write-Host "  1. NVIDIA VSS Blueprint backend"
    Write-Host "  2. Sports Analysis frontend"
    Write-Host ""
    Write-Host "Requirements:"
    Write-Host "  - Windows OS"
    Write-Host "  - RTX PRO 6000 GPU (or compatible)"
    Write-Host "  - NVIDIA NGC API key"
    Write-Host "  - Internet connection"
    Write-Host "  - Docker Desktop"
    Write-Host ""

    $continue = Read-Host "Continue? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Print-Info "Installation cancelled"
        exit 0
    }

    # Step 1: Check GPU
    if (-not (Test-GPU)) {
        exit 1
    }

    # Step 2: Install Docker
    Install-Docker

    # Step 3: Install system dependencies
    Install-Dependencies

    # Step 4: Prompt for API keys
    $NGC_API_KEY = Prompt-APIKeys

    # Step 5: Detect host IP
    $HOST_IP = Detect-HostIP

    # Step 6: Setup VSS Blueprint
    Setup-VSSBlueprint -ApiKey $NGC_API_KEY -HostIP $HOST_IP

    # Step 7: Deploy VSS Backend
    if (-not (Deploy-VSSBackend)) {
        Print-Error "VSS backend deployment failed"
        exit 1
    }

    # Step 8: Setup Sports Frontend
    Setup-SportsFrontend

    # Step 9: Deploy Sports Frontend
    Deploy-SportsFrontend -HostIP $HOST_IP

    # Step 10: Verify deployment
    Verify-Deployment

    # Step 11: Print summary
    Print-Summary -HostIP $HOST_IP
}

# Run main function
Main
