import { useState, useRef, useEffect } from 'react';
import { streamChatWithAgent } from '../api/vssClient';
import './ChatInterface.css';

function ChatInterface({ chatHistory, onChatMessage, uploadedVideos, isConnected }) {
  const [message, setMessage] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);
  const [currentResponse, setCurrentResponse] = useState('');
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [chatHistory, currentResponse]);

  const handleSendMessage = async () => {
    if (!message.trim() || !isConnected) return;

    const userMessage = {
      role: 'user',
      content: message,
      timestamp: new Date().toISOString(),
    };

    onChatMessage(userMessage);
    setMessage('');
    setIsStreaming(true);
    setCurrentResponse('');

    try {
      let fullResponse = '';

      await streamChatWithAgent(
        message,
        (chunk) => {
          if (chunk.content) {
            fullResponse += chunk.content;
            setCurrentResponse(fullResponse);
          }
        },
        null // session_id - can be enhanced for conversation continuity
      );

      const assistantMessage = {
        role: 'assistant',
        content: fullResponse,
        timestamp: new Date().toISOString(),
      };

      onChatMessage(assistantMessage);
      setCurrentResponse('');
    } catch (error) {
      console.error('Chat error:', error);
      const errorMessage = {
        role: 'assistant',
        content: 'Sorry, I encountered an error processing your request. Please try again.',
        timestamp: new Date().toISOString(),
      };
      onChatMessage(errorMessage);
    } finally {
      setIsStreaming(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const getPromptSuggestions = () => {
    const suggestions = [
      'Analyze the player movements in this video',
      'What are the key tactical patterns shown?',
      'Summarize the game highlights',
      'Identify any unusual plays or strategies',
      'Compare performance metrics',
    ];

    if (uploadedVideos.length > 0) {
      return suggestions;
    }

    return [
      'Upload a video to start analysis',
      'I can help analyze sports footage',
      'Supports video, YouTube links, and PDFs',
    ];
  };

  return (
    <div className="chat-interface">
      <h2 className="section-title">🏆 Sports Insights Chat</h2>

      <div className="chat-container">
        <div className="messages-container">
          {chatHistory.length === 0 && (
            <div className="welcome-message">
              <div className="welcome-icon">⚽</div>
              <h3>Welcome to Sports Analysis AI</h3>
              <p>
                Upload sports content (videos, YouTube links, or PDFs) and ask me to
                extract insights, analyze tactics, or summarize key moments.
              </p>
              <div className="suggestions">
                {getPromptSuggestions().map((suggestion, index) => (
                  <button
                    key={index}
                    className="suggestion-button"
                    onClick={() => setMessage(suggestion)}
                    disabled={!isConnected}
                  >
                    {suggestion}
                  </button>
                ))}
              </div>
            </div>
          )}

          {chatHistory.map((msg, index) => (
            <div
              key={index}
              className={`message ${msg.role === 'user' ? 'user-message' : 'assistant-message'}`}
            >
              <div className="message-header">
                <span className="message-role">
                  {msg.role === 'user' ? '👤 You' : '🤖 AI Analyst'}
                </span>
                <span className="message-time">
                  {new Date(msg.timestamp).toLocaleTimeString()}
                </span>
              </div>
              <div className="message-content">{msg.content}</div>
            </div>
          ))}

          {isStreaming && currentResponse && (
            <div className="message assistant-message streaming">
              <div className="message-header">
                <span className="message-role">🤖 AI Analyst</span>
                <span className="message-time">Generating...</span>
              </div>
              <div className="message-content">{currentResponse}</div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        <div className="input-container">
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder={
              isConnected
                ? 'Ask about the uploaded sports content...'
                : 'Waiting for connection to VSS agent...'
            }
            disabled={!isConnected || isStreaming}
            className="message-input"
            rows={3}
          />
          <button
            className="send-button"
            onClick={handleSendMessage}
            disabled={!isConnected || isStreaming || !message.trim()}
          >
            {isStreaming ? '⏳' : '📤'}
          </button>
        </div>
      </div>

      {uploadedVideos.length > 0 && (
        <div className="context-info">
          <span className="context-label">📊 Analyzing {uploadedVideos.length} source(s)</span>
        </div>
      )}
    </div>
  );
}

export default ChatInterface;
