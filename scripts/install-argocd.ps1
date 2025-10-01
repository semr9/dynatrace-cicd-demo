# Install ArgoCD on AKS Cluster
# This script is called by Terraform after AKS creation

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installing ArgoCD on AKS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create argocd namespace
Write-Host "Creating ArgoCD namespace..." -ForegroundColor Yellow
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create ArgoCD namespace" -ForegroundColor Red
    exit 1
}

# Install ArgoCD
Write-Host "Installing ArgoCD manifests..." -ForegroundColor Yellow
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install ArgoCD" -ForegroundColor Red
    exit 1
}

# Wait for ArgoCD to be ready
Write-Host "Waiting for ArgoCD server to be ready (this may take 2-3 minutes)..." -ForegroundColor Yellow
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

if ($LASTEXITCODE -ne 0) {
    Write-Host "ArgoCD deployment timeout" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ArgoCD Installed Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Get ArgoCD admin password with:" -ForegroundColor Cyan
Write-Host "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }" -ForegroundColor Gray
Write-Host ""
