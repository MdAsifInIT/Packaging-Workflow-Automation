# Check if Docker is installed
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed or not in the PATH. Please install Docker Desktop."
    exit 1
}

# Check if Docker Compose is available
if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
    Write-Error "Docker Compose is not installed. Please install Docker Compose."
    exit 1
}

Write-Host "Starting local development environment..."
docker-compose up -d

Write-Host "`nEnvironment started successfully!"
Write-Host "-----------------------------------"
Write-Host "n8n: http://localhost:5678"
Write-Host "  User: admin"
Write-Host "  Pass: password"
Write-Host "Jenkins: http://localhost:8080"
Write-Host "  (Check logs for initial admin password: docker-compose logs jenkins)"
Write-Host "-----------------------------------"
