import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_VSS_API_URL || 'http://localhost:8000';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 300000, // 5 minutes for video uploads
});

// Health check
export const checkHealth = async () => {
  try {
    const response = await apiClient.get('/health');
    return response.data;
  } catch (error) {
    console.error('Health check failed:', error);
    throw error;
  }
};

// Get version
export const getVersion = async () => {
  try {
    const response = await apiClient.get('/api/v1/version');
    return response.data;
  } catch (error) {
    console.error('Version check failed:', error);
    throw error;
  }
};

// Video upload - Get upload URL
export const getVideoUploadUrl = async (filename) => {
  try {
    const response = await apiClient.post('/api/v1/videos', { filename });
    return response.data;
  } catch (error) {
    console.error('Failed to get upload URL:', error);
    throw error;
  }
};

// Upload video chunk
export const uploadVideoChunk = async (uploadUrl, chunk, chunkIndex, totalChunks, filename) => {
  try {
    const formData = new FormData();
    formData.append('chunk', chunk);
    formData.append('chunkIndex', chunkIndex);
    formData.append('totalChunks', totalChunks);
    formData.append('filename', filename);

    const response = await axios.post(uploadUrl, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      timeout: 300000,
    });
    return response.data;
  } catch (error) {
    console.error('Failed to upload chunk:', error);
    throw error;
  }
};

// Complete video upload and trigger processing
export const completeVideoUpload = async (sensorId, filename, metadata = {}) => {
  try {
    const response = await apiClient.post(`/api/v1/videos/${sensorId}/complete`, {
      filename,
      metadata,
    });
    return response.data;
  } catch (error) {
    console.error('Failed to complete upload:', error);
    throw error;
  }
};

// Get video analysis status
export const getAnalysisStatus = async (videoId) => {
  try {
    const response = await apiClient.get(`/api/v1/videos/${videoId}/status`);
    return response.data;
  } catch (error) {
    console.error('Failed to get analysis status:', error);
    throw error;
  }
};

// Get video analysis results
export const getAnalysisResults = async (videoId) => {
  try {
    const response = await apiClient.get(`/api/v1/videos/${videoId}/results`);
    return response.data;
  } catch (error) {
    console.error('Failed to get analysis results:', error);
    throw error;
  }
};

// Process YouTube URL
export const processYouTubeUrl = async (url, metadata = {}) => {
  try {
    const response = await apiClient.post('/api/v1/videos/youtube', {
      url,
      metadata,
    });
    return response.data;
  } catch (error) {
    console.error('Failed to process YouTube URL:', error);
    throw error;
  }
};

// Chat with VSS agent
export const chatWithAgent = async (message, sessionId = null, videoId = null) => {
  try {
    const response = await apiClient.post('/v1/chat', {
      message,
      session_id: sessionId,
      video_id: videoId,
    });
    return response.data;
  } catch (error) {
    console.error('Failed to chat with agent:', error);
    throw error;
  }
};

// Stream chat responses
export const streamChatWithAgent = async (message, onChunk, sessionId = null, videoId = null) => {
  try {
    const response = await fetch(`${API_BASE_URL}/v1/chat/stream`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message,
        session_id: sessionId,
        video_id: videoId,
      }),
    });

    const reader = response.body.getReader();
    const decoder = new TextDecoder();

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split('\n');

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6);
          if (data === '[DONE]') {
            return;
          }
          try {
            const parsed = JSON.parse(data);
            onChunk(parsed);
          } catch (e) {
            console.error('Error parsing chunk:', e);
          }
        }
      }
    }
  } catch (error) {
    console.error('Failed to stream chat:', error);
    throw error;
  }
};

// Training API - Add sport-specific knowledge
export const addSportKnowledge = async (sport, knowledge) => {
  try {
    const response = await apiClient.post('/api/v1/training/knowledge', {
      sport,
      knowledge,
    });
    return response.data;
  } catch (error) {
    console.error('Failed to add sport knowledge:', error);
    throw error;
  }
};

// Training API - Upload training video
export const uploadTrainingVideo = async (file, sport, metadata = {}) => {
  try {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('sport', sport);
    formData.append('metadata', JSON.stringify(metadata));

    const response = await apiClient.post('/api/v1/training/videos', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      timeout: 300000,
    });
    return response.data;
  } catch (error) {
    console.error('Failed to upload training video:', error);
    throw error;
  }
};

// Get list of supported sports
export const getSupportedSports = async () => {
  try {
    const response = await apiClient.get('/api/v1/sports');
    return response.data;
  } catch (error) {
    console.error('Failed to get supported sports:', error);
    throw error;
  }
};

export default apiClient;
