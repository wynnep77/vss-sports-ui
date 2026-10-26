# VSS Sports Analysis UI

A professional web interface for analyzing sports videos using NVIDIA's VSS (Video Search and Summarization) technology.

## Features

- **Video Analysis**: Upload local videos or provide YouTube URLs for AI-powered analysis
- **Training Module**: Add sport-specific knowledge and upload training videos to improve model accuracy
- **AI Chat Interface**: Query video insights with natural language conversations
- **Dashboard**: Overview of analysis status, statistics, and recent activities

## Prerequisites

- NVIDIA VSS Blueprint installed on your server
- Node.js 18+ and npm for local development
- Docker and Docker Compose for deployment

## Starting the VSS Backend

Before running the Sports UI, ensure the VSS Blueprint backend is running:

1. **If VSS Blueprint is already installed**, use the provided startup script:
```bash
cd /home/demouser/vss-sports-ui
chmod +x start-vss-backend.sh
./start-vss-backend.sh
```

2. **Or manually start VSS Blueprint**:
```bash
cd /home/demouser/video-search-and-summarization/deploy/docker
docker compose up -d
```

3. **Verify the backend is running**:
```bash
curl http://localhost:8000/health
```

The startup script automatically configures required environment variables:
- LLM_MODE, LLM_NAME, LLM_DEVICE_ID
- VLM_MODE, VLM_NAME, VLM_DEVICE_ID
- VST_MODE, VST_NAME
- Network configuration (HOST_IP, EXTERNAL_IP, INTERNAL_IP)
- Service ports and data directories

## Quick Setup

Run the setup script to configure the environment:

**Linux/Mac:**
```bash
chmod +x setup.sh
./setup.sh
```

**Windows:**
```cmd
setup.bat
```

The script will guide you through:
- Creating the .env file
- Setting the VSS backend URL
- Choosing between local development or Docker deployment

## Local Development

1. Install dependencies:
```bash
npm install
```

2. Configure environment variables (or use setup script):
```bash
cp .env.example .env
# Edit .env and set VITE_VSS_API_URL to your VSS backend URL
```

3. Start development server:
```bash
npm run dev
```

The application will be available at `http://localhost:3000`

## Docker Deployment

1. Build and run with Docker Compose:
```bash
docker-compose up -d
```

2. The application will be available at `http://localhost:8080`

## Configuration

Environment variables:

- `VITE_VSS_API_URL`: URL of the VSS backend API (default: `http://localhost:8000`)

## Architecture

- **Frontend**: React + Vite + Tailwind CSS
- **API Integration**: Axios-based client for VSS backend communication
- **Deployment**: Docker + nginx

## API Endpoints

The application integrates with the following VSS API endpoints:

- `GET /health` - Health check
- `POST /api/v1/videos` - Get video upload URL
- `POST /api/v1/videos/{sensorId}/complete` - Complete video upload
- `GET /api/v1/videos/{videoId}/status` - Get analysis status
- `GET /api/v1/videos/{videoId}/results` - Get analysis results
- `POST /api/v1/videos/youtube` - Process YouTube URL
- `POST /v1/chat` - Chat with VSS agent
- `POST /v1/chat/stream` - Stream chat responses
- `POST /api/v1/training/knowledge` - Add sport knowledge
- `POST /api/v1/training/videos` - Upload training video
- `GET /api/v1/sports` - Get supported sports

## License

MIT
