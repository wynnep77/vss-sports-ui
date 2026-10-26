@echo off
REM VSS Sports UI Setup Script for Windows

echo VSS Sports Analysis UI - Setup
echo ================================
echo.

REM Check if .env exists
if not exist .env (
    echo Creating .env file from .env.example...
    copy .env.example .env
    echo [OK] .env file created
) else (
    echo [OK] .env file already exists
)

echo.
echo Configuration Options:
echo 1. Local Development (Vite dev server)
echo 2. Docker Deployment
echo.
set /p OPTION="Select option (1 or 2): "

if "%OPTION%"=="1" (
    echo.
    echo Setting up for local development...
    echo.
    set /p VSS_URL="Enter VSS Backend URL (default: http://localhost:8000): "
    if "%VSS_URL%"=="" set VSS_URL=http://localhost:8000
    
    REM Update .env file
    powershell -Command "(Get-Content .env) -replace '^VITE_VSS_API_URL=.*', 'VITE_VSS_API_URL=%VSS_URL%' | Set-Content .env"
    echo [OK] VITE_VSS_API_URL set to %VSS_URL%
    
    echo.
    echo To start the development server:
    echo   npm install
    echo   npm run dev
    echo.
    echo The application will be available at http://localhost:3000
) else if "%OPTION%"=="2" (
    echo.
    echo Setting up for Docker deployment...
    echo.
    echo Docker Compose will automatically configure:
    echo   - VITE_VSS_API_URL=http://host.docker.internal:8000
    echo   - Port mapping: 8080:80
    echo.
    echo To deploy with Docker:
    echo   docker-compose up -d
    echo.
    echo The application will be available at http://localhost:8080
) else (
    echo Invalid option. Exiting.
    exit /b 1
)

echo.
echo Setup complete!
