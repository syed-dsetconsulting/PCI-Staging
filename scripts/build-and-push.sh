#!/bin/bash

# Build and Push Script for PCI Application
# Usage: ./scripts/build-and-push.sh [ACR_NAME] [TAG]

set -e

# Default values
ACR_NAME=${1:-"pciregistry"}
TAG=${2:-"latest"}

echo "🚀 Building and pushing PCI application images..."
echo "Registry: $ACR_NAME.azurecr.io"
echo "Tag: $TAG"

# Login to Azure Container Registry
echo "📋 Logging into Azure Container Registry..."
az acr login --name $ACR_NAME

# Build and push backend
echo "🔨 Building backend image..."
cd PCI-backend
az acr build --registry $ACR_NAME --image pci-backend:$TAG .
cd ..

# Build and push frontend
echo "🔨 Building frontend image..."
cd PCI
az acr build --registry $ACR_NAME --image pci-frontend:$TAG .
cd ..

echo "✅ Successfully built and pushed all images!"
echo "Backend: $ACR_NAME.azurecr.io/pci-backend:$TAG"
echo "Frontend: $ACR_NAME.azurecr.io/pci-frontend:$TAG"
