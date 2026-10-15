# VSS Sports Analysis UI

A custom React frontend for the NVIDIA Video Search and Summarization (VSS) blueprint, designed specifically for sports analysis. This interface allows you to upload sports content (videos, YouTube links, PDFs) and extract insights using AI-powered analysis.

## Features

- 🎥 **Video Upload**: Chunked video upload with progress tracking
- 📺 **YouTube Integration**: Submit YouTube URLs for analysis
- 📄 **PDF Support**: Upload PDF documents for analysis
- 🤖 **AI Chat Interface**: Natural language interface to query sports insights
- 🏆 **Sports-Themed UI**: Custom dark theme with sports branding
- 📊 **Real-time Streaming**: Streaming responses from the VSS agent
- 🚀 **Docker Deployment**: Easy deployment with Docker and nginx on port 80

## Prerequisites

- NVIDIA VSS Blueprint deployed and running (see [Deployment Guide](#deployment-guide))
- Node.js 18+ (for local development)
- Docker and Docker Compose (for production deployment)
- At least 1x RTX PRO 6000 GPU for the VSS backend

## Quick Start

### Local Development

1. **Install dependencies:**
   ```bash
   cd vss-sports-ui
   npm install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env to set VITE_API_BASE_URL to your VSS agent endpoint
   ```

3. **Start development server:**
   ```bash
   npm run dev
   ```

4. Open http://localhost:3000 in your browser

### Docker Deployment (Production)

1. **Build and run with Docker Compose:**
   ```bash
   cd vss-sports-ui
   docker-compose up -d
   ```

2. Access the UI at http://localhost (port 80)

3. View logs:
   ```bash
   docker-compose logs -f
   ```

## Deployment Guide for Ubuntu with RTX PRO 6000

### Step 1: Deploy NVIDIA VSS Blueprint

Follow the official NVIDIA VSS Blueprint deployment instructions for Ubuntu:

```bash
# Clone the VSS blueprint repository
git clone https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization.git
cd video-search-and-summarization

# Follow the deployment guide in the repository
# This typically involves:
# 1. Setting up NVIDIA drivers and Docker
# 2. Configuring environment variables
# 3. Deploying with Docker Compose or Helm
```

### Step 2: Deploy the Sports UI

Once the VSS agent is running (typically on port 8000):

```bash
# Clone or copy this vss-sports-ui directory to your Ubuntu machine
cd vss-sports-ui

# Build the Docker image
docker build -t vss-sports-ui:latest .

# Run the container
docker run -d \
  --name vss-sports-ui \
  -p 80:80 \
  -e VITE_API_BASE_URL=http://localhost:8000 \
  --add-host=host.docker.internal:host-gateway \
  vss-sports-ui:latest
```

### Step 3: Access the UI

Open your browser and navigate to:
- http://your-ubuntu-ip (for production)
- http://localhost (if accessing from the same machine)

## Configuration

### Environment Variables

- `VITE_API_BASE_URL`: The URL of the VSS agent API (default: `http://localhost:8000`)

### Nginx Configuration

The nginx configuration in `nginx.conf` proxies API requests to the VSS agent. If your VSS agent is running on a different host or port, update the proxy_pass directives:

```nginx
location /api/ {
    proxy_pass http://your-vss-agent-host:8000;
    # ... other configuration
}
```

## Architecture

```
┌─────────────────┐
│   Browser      │
│   (Port 80)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Nginx (Docker) │
│  vss-sports-ui  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  VSS Agent      │
│  (Port 8000)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  VLM/LLM NIMs   │
│  (GPU)          │
└─────────────────┘
```

## API Integration

The frontend integrates with the VSS agent through the following endpoints:

- `GET /health` - Health check
- `GET /api/v1/version` - Get VSS version
- `POST /api/v1/videos` - Get video upload URL
- `POST /api/v1/videos/{sensor_id}/complete` - Complete video upload
- `POST /v1/chat` - Send chat message
- `POST /v1/chat/stream` - Stream chat responses

## Development

### Project Structure

```
vss-sports-ui/
├── src/
│   ├── api/
│   │   └── vssClient.js       # API client for VSS endpoints
│   ├── components/
│   │   ├── Header.jsx         # Header with connection status
│   │   ├── UploadSection.jsx  # File upload interface
│   │   └── ChatInterface.jsx  # Chat interface
│   ├── App.jsx                # Main application
│   ├── App.css
│   ├── main.jsx
│   └── index.css
├── Dockerfile
├── docker-compose.yml
├── nginx.conf
├── package.json
└── vite.config.js
```

### Adding New Features

1. **New API endpoints**: Add to `src/api/vssClient.js`
2. **New components**: Add to `src/components/`
3. **Styling**: Follow the existing dark theme with #e94560 accent color

## Troubleshooting

### Connection Issues

If the UI shows "Disconnected":

1. Verify the VSS agent is running: `curl http://localhost:8000/health`
2. Check the `VITE_API_BASE_URL` environment variable
3. Ensure nginx proxy configuration is correct
4. Check Docker container logs: `docker logs vss-sports-ui`

### Upload Failures

If video uploads fail:

1. Check VST (Video Storage Toolkit) is running
2. Verify `VST_INTERNAL_URL` is configured correctly
3. Check browser console for error messages
4. Ensure sufficient disk space

### Chat Not Working

If the chat interface doesn't respond:

1. Verify LLM/VLM NIMs are running
2. Check `LLM_BASE_URL` and `VLM_BASE_URL` configuration
3. Review VSS agent logs for errors
4. Ensure GPU is accessible and not out of memory

## License

This frontend is provided as part of the NVIDIA VSS Blueprint ecosystem. See the main VSS repository for licensing information.

## Support

For issues related to:
- **VSS Blueprint**: Refer to [NVIDIA VSS Documentation](https://docs.nvidia.com/vss/latest/index.html)
- **This UI**: Open an issue in your git repository

## Acknowledgments

Built on top of the [NVIDIA AI Blueprint for Video Search and Summarization](https://github.com/NVIDIA-AI-Blueprints/video-search-and-summarization)
