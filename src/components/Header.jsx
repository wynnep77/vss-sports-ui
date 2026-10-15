import './Header.css';

function Header({ isConnected, version }) {
  return (
    <header className="header">
      <div className="header-content">
        <div className="logo-section">
          <h1 className="logo">⚽ Sports Analysis AI</h1>
          <p className="tagline">Powered by NVIDIA VSS Blueprint</p>
        </div>
        <div className="status-section">
          <div className={`status-indicator ${isConnected ? 'connected' : 'disconnected'}`}>
            <span className="status-dot"></span>
            <span className="status-text">
              {isConnected ? 'Connected' : 'Disconnected'}
            </span>
          </div>
          {version && (
            <div className="version-info">
              <span className="version-label">VSS Version:</span>
              <span className="version-value">{version.version}</span>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

export default Header;
