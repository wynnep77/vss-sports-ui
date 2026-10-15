import { useState, useRef, useEffect } from 'react';
import { streamChatWithAgent } from '../api/vssClient';
import './ChatInterface.css';

function ChatInterface({ chatHistory, onChatMessage, uploadedVideos, isConnected }) {
  const [message, setMessage] = useState('');
  const [isStreaming, setIsStreaming] = useState(false);
  const [isGeneratingSummary, setIsGeneratingSummary] = useState(false);
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

  const generateExecutiveSummary = async () => {
    if (!isConnected || uploadedVideos.length === 0) {
      alert('Please upload content and ensure connection to VSS agent');
      return;
    }

    const videoList = uploadedVideos.map((v, i) => `${i + 1}. ${v.filename} (${v.type})`).join('\n');

    const summaryPrompt = `Generate a comprehensive executive summary for the following sports content:

${videoList}

Please provide the analysis in the following structured format:

# EXECUTIVE SUMMARY

## KEY STATISTICS
- Total content analyzed: ${uploadedVideos.length} items
- Content types: ${uploadedVideos.map(v => v.type).join(', ')}
- [Additional relevant statistics from the analysis]

## OVERALL SUMMARY
[Brief overall summary of all content analyzed]

## PER-CONTENT ANALYSIS
${uploadedVideos.map((video, index) => `
### ${index + 1}. ${video.filename}
**Type:** ${video.type.toUpperCase()}
**Summary:** [Detailed summary of this specific content]
**Key Findings:** [Key insights from this content]
`).join('\n')}

## OPPORTUNITIES
- [List identified opportunities from the analysis]
- [Strategic opportunities]
- [Performance improvement opportunities]

## RISKS
- [List identified risks from the analysis]
- [Performance risks]
- [Strategic risks]

## RECOMMENDATIONS
- [Actionable recommendations based on the analysis]
- [Priority recommendations]
- [Long-term strategic recommendations]

## CONCLUSION
[Overall conclusion and next steps]`;

    const userMessage = {
      role: 'user',
      content: summaryPrompt,
      timestamp: new Date().toISOString(),
      isExecutiveSummary: true,
    };

    onChatMessage(userMessage);
    setIsGeneratingSummary(true);
    setIsStreaming(true);
    setCurrentResponse('');

    try {
      let fullResponse = '';

      await streamChatWithAgent(
        summaryPrompt,
        (chunk) => {
          if (chunk.content) {
            fullResponse += chunk.content;
            setCurrentResponse(fullResponse);
          }
        },
        null
      );

      const assistantMessage = {
        role: 'assistant',
        content: fullResponse,
        timestamp: new Date().toISOString(),
        isExecutiveSummary: true,
      };

      onChatMessage(assistantMessage);
      setCurrentResponse('');
    } catch (error) {
      console.error('Executive summary generation error:', error);
      const errorMessage = {
        role: 'assistant',
        content: 'Sorry, I encountered an error generating the executive summary. Please try again.',
        timestamp: new Date().toISOString(),
        isExecutiveSummary: true,
      };
      onChatMessage(errorMessage);
    } finally {
      setIsGeneratingSummary(false);
      setIsStreaming(false);
    }
  };

  const downloadExecutiveSummary = (content, filename) => {
    const blob = new Blob([content], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `executive-summary-${new Date().toISOString().split('T')[0]}.md`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div className="chat-interface">
      <div className="chat-header">
        <h2 className="section-title">🏆 Sports Insights Chat</h2>
        <button
          className="exec-summary-button"
          onClick={generateExecutiveSummary}
          disabled={!isConnected || isStreaming || uploadedVideos.length === 0}
          title="Generate comprehensive executive summary of all uploaded content"
        >
          {isGeneratingSummary ? '⏳ Generating...' : '📊 Generate Executive Summary'}
        </button>
      </div>

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
              className={`message ${msg.role === 'user' ? 'user-message' : 'assistant-message'} ${msg.isExecutiveSummary ? 'executive-summary' : ''}`}
            >
              <div className="message-header">
                <span className="message-role">
                  {msg.role === 'user' ? '👤 You' : msg.isExecutiveSummary ? '📊 Executive Summary' : '🤖 AI Analyst'}
                </span>
                <div className="message-header-actions">
                  {msg.isExecutiveSummary && msg.role === 'assistant' && (
                    <button
                      className="download-button"
                      onClick={() => downloadExecutiveSummary(msg.content, msg.filename)}
                      title="Download as Markdown"
                    >
                      📥 Download
                    </button>
                  )}
                  <span className="message-time">
                    {new Date(msg.timestamp).toLocaleTimeString()}
                  </span>
                </div>
              </div>
              <div className="message-content">
                {msg.isExecutiveSummary ? (
                  <div className="executive-summary-content">
                    {msg.content}
                  </div>
                ) : (
                  msg.content
                )}
              </div>
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
