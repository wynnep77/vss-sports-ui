import { useState } from 'react';
import {
  getVideoUploadUrl,
  uploadVideoChunk,
  completeVideoUpload,
} from '../api/vssClient';
import './UploadSection.css';

function UploadSection({ onVideoUpload, uploadedVideos, isConnected }) {
  const [uploadType, setUploadType] = useState('video');
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [youtubeUrl, setYoutubeUrl] = useState('');
  const [pdfFile, setPdfFile] = useState(null);
  const [videoFile, setVideoFile] = useState(null);

  const CHUNK_SIZE = 5 * 1024 * 1024; // 5MB chunks

  const handleVideoFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setVideoFile(file);
    }
  };

  const handlePdfFileChange = (e) => {
    const file = e.target.files[0];
    if (file && file.type === 'application/pdf') {
      setPdfFile(file);
    } else {
      alert('Please select a valid PDF file');
    }
  };

  const uploadVideoInChunks = async (file) => {
    const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
    let sensorId = null;

    try {
      // Step 1: Get upload URL
      const { url } = await getVideoUploadUrl(file.name);
      setUploadProgress(10);

      // Step 2: Upload chunks
      for (let i = 0; i < totalChunks; i++) {
        const start = i * CHUNK_SIZE;
        const end = Math.min(start + CHUNK_SIZE, file.size);
        const chunk = file.slice(start, end);

        const response = await uploadVideoChunk(url, chunk, i, totalChunks, file.name);

        if (response.sensorId) {
          sensorId = response.sensorId;
        }

        const progress = Math.round(((i + 1) / totalChunks) * 80) + 10;
        setUploadProgress(progress);
      }

      // Step 3: Complete upload
      if (sensorId) {
        await completeVideoUpload(sensorId, file.name);
        setUploadProgress(100);

        onVideoUpload({
          id: sensorId,
          filename: file.name,
          type: 'video',
          uploadDate: new Date().toISOString(),
        });

        alert('Video uploaded successfully!');
      }
    } catch (error) {
      console.error('Upload failed:', error);
      alert('Upload failed: ' + error.message);
      setUploadProgress(0);
    }
  };

  const handleVideoUpload = async () => {
    if (!videoFile) {
      alert('Please select a video file');
      return;
    }

    setIsUploading(true);
    setUploadProgress(0);

    await uploadVideoInChunks(videoFile);

    setIsUploading(false);
    setVideoFile(null);
  };

  const handleYoutubeSubmit = () => {
    if (!youtubeUrl) {
      alert('Please enter a YouTube URL');
      return;
    }

    // For YouTube, we'll need to implement YouTube download/processing
    // This is a placeholder - you'll need to add backend support for YouTube
    onVideoUpload({
      id: Date.now().toString(),
      filename: youtubeUrl,
      type: 'youtube',
      uploadDate: new Date().toISOString(),
    });

    alert('YouTube URL submitted for processing');
    setYoutubeUrl('');
  };

  const handlePdfUpload = async () => {
    if (!pdfFile) {
      alert('Please select a PDF file');
      return;
    }

    // For PDF, we'll need to implement PDF processing
    // This is a placeholder - you'll need to add backend support for PDF
    onVideoUpload({
      id: Date.now().toString(),
      filename: pdfFile.name,
      type: 'pdf',
      uploadDate: new Date().toISOString(),
    });

    alert('PDF uploaded successfully!');
    setPdfFile(null);
  };

  const handleUpload = () => {
    switch (uploadType) {
      case 'video':
        handleVideoUpload();
        break;
      case 'youtube':
        handleYoutubeSubmit();
        break;
      case 'pdf':
        handlePdfUpload();
        break;
      default:
        break;
    }
  };

  return (
    <div className="upload-section">
      <h2 className="section-title">📤 Upload Sports Content</h2>

      <div className="upload-tabs">
        <button
          className={`tab-button ${uploadType === 'video' ? 'active' : ''}`}
          onClick={() => setUploadType('video')}
        >
          🎥 Video
        </button>
        <button
          className={`tab-button ${uploadType === 'youtube' ? 'active' : ''}`}
          onClick={() => setUploadType('youtube')}
        >
          📺 YouTube
        </button>
        <button
          className={`tab-button ${uploadType === 'pdf' ? 'active' : ''}`}
          onClick={() => setUploadType('pdf')}
        >
          📄 PDF
        </button>
      </div>

      <div className="upload-content">
        {uploadType === 'video' && (
          <div className="upload-form">
            <div className="file-input-wrapper">
              <input
                type="file"
                accept="video/*"
                onChange={handleVideoFileChange}
                disabled={!isConnected || isUploading}
                id="video-input"
              />
              <label htmlFor="video-input" className="file-input-label">
                {videoFile ? videoFile.name : 'Choose video file...'}
              </label>
            </div>
            <button
              className="upload-button"
              onClick={handleVideoUpload}
              disabled={!isConnected || isUploading || !videoFile}
            >
              {isUploading ? 'Uploading...' : 'Upload Video'}
            </button>
          </div>
        )}

        {uploadType === 'youtube' && (
          <div className="upload-form">
            <input
              type="text"
              placeholder="Enter YouTube URL..."
              value={youtubeUrl}
              onChange={(e) => setYoutubeUrl(e.target.value)}
              disabled={!isConnected}
              className="url-input"
            />
            <button
              className="upload-button"
              onClick={handleYoutubeSubmit}
              disabled={!isConnected || !youtubeUrl}
            >
              Submit URL
            </button>
          </div>
        )}

        {uploadType === 'pdf' && (
          <div className="upload-form">
            <div className="file-input-wrapper">
              <input
                type="file"
                accept="application/pdf"
                onChange={handlePdfFileChange}
                disabled={!isConnected || isUploading}
                id="pdf-input"
              />
              <label htmlFor="pdf-input" className="file-input-label">
                {pdfFile ? pdfFile.name : 'Choose PDF file...'}
              </label>
            </div>
            <button
              className="upload-button"
              onClick={handlePdfUpload}
              disabled={!isConnected || isUploading || !pdfFile}
            >
              Upload PDF
            </button>
          </div>
        )}

        {isUploading && (
          <div className="progress-container">
            <div className="progress-bar">
              <div
                className="progress-fill"
                style={{ width: `${uploadProgress}%` }}
              ></div>
            </div>
            <span className="progress-text">{uploadProgress}%</span>
          </div>
        )}
      </div>

      {uploadedVideos.length > 0 && (
        <div className="uploaded-videos">
          <h3 className="subsection-title">Uploaded Content</h3>
          <div className="video-list">
            {uploadedVideos.map((video) => (
              <div key={video.id} className="video-item">
                <span className="video-icon">
                  {video.type === 'video' && '🎥'}
                  {video.type === 'youtube' && '📺'}
                  {video.type === 'pdf' && '📄'}
                </span>
                <span className="video-name">{video.filename}</span>
                <span className="video-type">{video.type.toUpperCase()}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default UploadSection;
