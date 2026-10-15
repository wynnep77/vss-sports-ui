import { useState, useEffect } from 'react';
import Header from './components/Header';
import UploadSection from './components/UploadSection';
import ChatInterface from './components/ChatInterface';
import { checkHealth, getVersion } from './api/vssClient';
import './App.css';

function App() {
  const [isConnected, setIsConnected] = useState(false);
  const [version, setVersion] = useState(null);
  const [uploadedVideos, setUploadedVideos] = useState([]);
  const [chatHistory, setChatHistory] = useState([]);

  useEffect(() => {
    checkConnection();
  }, []);

  const checkConnection = async () => {
    try {
      await checkHealth();
      const versionData = await getVersion();
      setVersion(versionData);
      setIsConnected(true);
    } catch (error) {
      console.error('Failed to connect to VSS agent:', error);
      setIsConnected(false);
    }
  };

  const handleVideoUpload = (videoData) => {
    setUploadedVideos((prev) => [...prev, videoData]);
  };

  const handleChatMessage = (message) => {
    setChatHistory((prev) => [...prev, message]);
  };

  return (
    <div className="app">
      <Header isConnected={isConnected} version={version} />
      <main className="main-content">
        <div className="content-grid">
          <UploadSection
            onVideoUpload={handleVideoUpload}
            uploadedVideos={uploadedVideos}
            isConnected={isConnected}
          />
          <ChatInterface
            chatHistory={chatHistory}
            onChatMessage={handleChatMessage}
            uploadedVideos={uploadedVideos}
            isConnected={isConnected}
          />
        </div>
      </main>
    </div>
  );
}

export default App;
