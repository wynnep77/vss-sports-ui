import { useState } from 'react';
import { Upload, Link, Play, CheckCircle, AlertCircle, Loader2 } from 'lucide-react';
import { getVideoUploadUrl, uploadVideoChunk, completeVideoUpload, processYouTubeUrl, getAnalysisStatus } from '../api/vssClient';

export default function AnalysisPage() {
  const [uploadMethod, setUploadMethod] = useState('file'); // 'file' or 'youtube'
  const [file, setFile] = useState(null);
  const [youtubeUrl, setYoutubeUrl] = useState('');
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploadStatus, setUploadStatus] = useState('idle'); // idle, uploading, processing, completed, error
  const [errorMessage, setErrorMessage] = useState('');
  const [analysisResults, setAnalysisResults] = useState(null);

  const handleFileSelect = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile) {
      setFile(selectedFile);
      setUploadStatus('idle');
      setErrorMessage('');
    }
  };

  const handleUpload = async () => {
    if (uploadMethod === 'file' && !file) {
      setErrorMessage('Please select a file');
      return;
    }
    if (uploadMethod === 'youtube' && !youtubeUrl) {
      setErrorMessage('Please enter a YouTube URL');
      return;
    }

    setUploadStatus('uploading');
    setUploadProgress(0);
    setErrorMessage('');

    try {
      if (uploadMethod === 'file') {
        await uploadFile();
      } else {
        await processYouTube();
      }
    } catch (error) {
      setUploadStatus('error');
      setErrorMessage(error.message || 'Upload failed');
    }
  };

  const uploadFile = async () => {
    const CHUNK_SIZE = 10 * 1024 * 1024; // 10MB chunks
    const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
    const filename = file.name;

    // Get upload URL
    const { upload_url, sensor_id } = await getVideoUploadUrl(filename);

    // Upload chunks
    for (let chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      const start = chunkIndex * CHUNK_SIZE;
      const end = Math.min(start + CHUNK_SIZE, file.size);
      const chunk = file.slice(start, end);

      await uploadVideoChunk(upload_url, chunk, chunkIndex, totalChunks, filename);
      setUploadProgress(((chunkIndex + 1) / totalChunks) * 100);
    }

    // Complete upload
    await completeVideoUpload(sensor_id, filename);
    setUploadStatus('processing');
    pollAnalysisStatus(sensor_id);
  };

  const processYouTube = async () => {
    const { video_id } = await processYouTubeUrl(youtubeUrl);
    setUploadStatus('processing');
    pollAnalysisStatus(video_id);
  };

  const pollAnalysisStatus = async (videoId) => {
    const pollInterval = setInterval(async () => {
      try {
        const status = await getAnalysisStatus(videoId);
        if (status.status === 'completed') {
          clearInterval(pollInterval);
          setUploadStatus('completed');
          const results = await getAnalysisResults(videoId);
          setAnalysisResults(results);
        } else if (status.status === 'failed') {
          clearInterval(pollInterval);
          setUploadStatus('error');
          setErrorMessage('Analysis failed');
        }
      } catch (error) {
        clearInterval(pollInterval);
        setUploadStatus('error');
        setErrorMessage('Failed to check status');
      }
    }, 5000);
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-gray-900">Video Analysis</h1>
        <p className="text-gray-600 mt-1">Upload or link a video for AI-powered sports analysis</p>
      </div>

      {/* Upload Method Selection */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex space-x-4 mb-6">
          <button
            onClick={() => setUploadMethod('file')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-lg transition-colors ${
              uploadMethod === 'file' ? 'bg-primary-50 text-primary-700' : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <Upload className="h-5 w-5" />
            <span>Upload File</span>
          </button>
          <button
            onClick={() => setUploadMethod('youtube')}
            className={`flex items-center space-x-2 px-4 py-2 rounded-lg transition-colors ${
              uploadMethod === 'youtube' ? 'bg-primary-50 text-primary-700' : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <Link className="h-5 w-5" />
            <span>YouTube URL</span>
          </button>
        </div>

        {uploadMethod === 'file' && (
          <div className="space-y-4">
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-primary-400 transition-colors">
              <Upload className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600 mb-2">Drag and drop a video file here, or click to select</p>
              <input
                type="file"
                accept="video/*"
                onChange={handleFileSelect}
                className="hidden"
                id="file-upload"
              />
              <label
                htmlFor="file-upload"
                className="inline-block px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 cursor-pointer"
              >
                Select File
              </label>
            </div>
            {file && (
              <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                <div className="flex items-center space-x-3">
                  <Play className="h-5 w-5 text-gray-400" />
                  <div>
                    <p className="font-medium text-gray-900">{file.name}</p>
                    <p className="text-sm text-gray-500">{(file.size / (1024 * 1024)).toFixed(2)} MB</p>
                  </div>
                </div>
                <button
                  onClick={() => setFile(null)}
                  className="text-red-600 hover:text-red-700"
                >
                  Remove
                </button>
              </div>
            )}
          </div>
        )}

        {uploadMethod === 'youtube' && (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                YouTube URL
              </label>
              <input
                type="url"
                value={youtubeUrl}
                onChange={(e) => setYoutubeUrl(e.target.value)}
                placeholder="https://www.youtube.com/watch?v=..."
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
            </div>
          </div>
        )}

        <button
          onClick={handleUpload}
          disabled={uploadStatus !== 'idle' || (!file && !youtubeUrl)}
          className="mt-6 w-full px-4 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
        >
          {uploadStatus === 'uploading' ? 'Uploading...' : 'Start Analysis'}
        </button>

        {uploadStatus === 'uploading' && (
          <div className="mt-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm text-gray-600">Uploading...</span>
              <span className="text-sm font-medium">{uploadProgress.toFixed(0)}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div
                className="bg-primary-600 h-2 rounded-full transition-all"
                style={{ width: `${uploadProgress}%` }}
              />
            </div>
          </div>
        )}

        {uploadStatus === 'processing' && (
          <div className="mt-4 flex items-center space-x-2 text-yellow-600">
            <Loader2 className="h-5 w-5 animate-spin" />
            <span>Processing video with AI...</span>
          </div>
        )}

        {uploadStatus === 'completed' && (
          <div className="mt-4 flex items-center space-x-2 text-green-600">
            <CheckCircle className="h-5 w-5" />
            <span>Analysis completed successfully!</span>
          </div>
        )}

        {uploadStatus === 'error' && (
          <div className="mt-4 flex items-center space-x-2 text-red-600">
            <AlertCircle className="h-5 w-5" />
            <span>{errorMessage}</span>
          </div>
        )}
      </div>

      {/* Analysis Results */}
      {analysisResults && (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Analysis Results</h2>
          <div className="space-y-4">
            <div>
              <h3 className="font-medium text-gray-900">Detected Events</h3>
              <ul className="mt-2 space-y-2">
                {analysisResults.events?.map((event, index) => (
                  <li key={index} className="text-sm text-gray-600">
                    {event.timestamp} - {event.type}
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h3 className="font-medium text-gray-900">Key Insights</h3>
              <p className="mt-2 text-sm text-gray-600">{analysisResults.insights}</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
