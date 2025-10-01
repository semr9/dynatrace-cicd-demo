# Build and Push Docker Images to ACR
# This script is called by Terraform after ACR creation
param(
    [string]$AcrLoginServer,
    [string]$AcrName
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building and Pushing Docker Images" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "ACR Server: $AcrLoginServer" -ForegroundColor Yellow
Write-Host "Logging in to ACR..." -ForegroundColor Cyan

az acr login --name $AcrName

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to login to ACR" -ForegroundColor Red
    exit 1
}

Write-Host "Login successful!" -ForegroundColor Green
Write-Host ""

# Define all services
$services = @(
    @{Name="frontend"; Path="../frontend"},
    @{Name="api-gateway"; Path="../backend/api-gateway"},
    @{Name="user-service"; Path="../backend/user-service"},
    @{Name="product-service"; Path="../backend/product-service"},
    @{Name="order-service"; Path="../backend/order-service"},
    @{Name="payment-service"; Path="../backend/payment-service"}
)

$total = $services.Count
$current = 0

foreach ($service in $services) {
    $current++
    Write-Host "[$current/$total] Building $($service.Name)..." -ForegroundColor Cyan
    
    $imageName = "$AcrLoginServer/$($service.Name):latest"
    
    docker build -t $imageName $service.Path
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to build $($service.Name)" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Pushing to ACR..." -ForegroundColor Yellow
    docker push $imageName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to push $($service.Name)" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  $($service.Name) complete!" -ForegroundColor Green
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "  All Images Built and Pushed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Images available in ACR:" -ForegroundColor Cyan
foreach ($service in $services) {
    Write-Host "  - $AcrLoginServer/$($service.Name):latest" -ForegroundColor White
}
Write-Host ""

