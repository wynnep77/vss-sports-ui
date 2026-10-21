import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';
const OLLAMA_ENABLED = import.meta.env.VITE_OLLAMA_ENABLED === 'true';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Ollama client for local LLM
const ollamaClient = axios.create({
  baseURL: 'http://localhost:11434',
  headers: {
    'Content-Type': 'application/json',
  },
});

// Health check
export const checkHealth = async () => {
  const response = await apiClient.get('/health');
  return response.data;
};

// Get version
export const getVersion = async () => {
  const response = await apiClient.get('/api/v1/version');
  return response.data;
};

// Video upload - Step 1: Get upload URL
export const getVideoUploadUrl = async (filename) => {
  const response = await apiClient.post('/api/v1/videos', { filename });
  return response.data;
};

// Video upload - Step 2: Upload chunks directly to VST
export const uploadVideoChunk = async (uploadUrl, chunk, chunkIndex, totalChunks, filename) => {
  const formData = new FormData();
  formData.append('chunk', chunk);
  formData.append('chunkIndex', chunkIndex);
  formData.append('totalChunks', totalChunks);
  formData.append('filename', filename);

  const response = await axios.post(uploadUrl, formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  });
  return response.data;
};

// Video upload - Step 3: Complete upload and trigger processing
export const completeVideoUpload = async (sensorId, filename, customParams = {}) => {
  const response = await apiClient.post(`/api/v1/videos/${sensorId}/complete`, {
    filename,
    custom_params: customParams,
  });
  return response.data;
};

// Chat with the agent for sports insights
export const chatWithAgent = async (message, sessionId = null) => {
  if (OLLAMA_ENABLED) {
    // Use Ollama for local LLM
    const response = await ollamaClient.post('/api/generate', {
      model: 'llama3',
      prompt: message,
      stream: false,
    });
    return {
      response: response.data.response,
      session_id: sessionId,
    };
  } else {
    // Use VSS agent
    const response = await apiClient.post('/v1/chat', {
      message,
      session_id: sessionId,
    });
    return response.data;
  }
};

// Stream chat responses
export const streamChatWithAgent = async (message, onChunk, sessionId = null) => {
  if (OLLAMA_ENABLED) {
    // Use Ollama for local LLM (streaming)
    const response = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'llama3',
        prompt: message,
        stream: true,
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
        if (line) {
          try {
            const parsed = JSON.parse(line);
            onChunk({ response: parsed.response, done: parsed.done });
            if (parsed.done) return;
          } catch (e) {
            console.error('Error parsing chunk:', e);
          }
        }
      }
    }
  } else {
    // Use VSS agent
    const response = await fetch(`${API_BASE_URL}/v1/chat/stream`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message,
        session_id: sessionId,
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
  }
};

export default apiClient;
