#!/bin/bash

# Deploy Script for PCI Application
# Usage: ./scripts/deploy.sh [ENVIRONMENT] [ACR_NAME] [TAG]

set -e

# Default values
ENVIRONMENT=${1:-"production"}
ACR_NAME=${2:-"pciregistry"}
TAG=${3:-"latest"}
NAMESPACE="pci-app"

if [ "$ENVIRONMENT" = "staging" ]; then
    NAMESPACE="pci-app-staging"
fi

echo "🚀 Deploying PCI application..."
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Registry: $ACR_NAME.azurecr.io"
echo "Tag: $TAG"

# Check if kubectl is configured
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Install NGINX Ingress Controller if not exists
echo "📋 Checking NGINX Ingress Controller..."
if ! kubectl get namespace ingress-nginx >/dev/null 2>&1; then
    echo "🔧 Installing NGINX Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --wait
fi

# Install cert-manager if not exists
echo "📋 Checking cert-manager..."
if ! kubectl get namespace cert-manager >/dev/null 2>&1; then
    echo "🔧 Installing cert-manager..."
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --version v1.13.0 \
        --set installCRDs=true \
        --wait
fi

# Deploy application using Helm
echo "🚀 Deploying application..."
helm upgrade --install pci-app-$ENVIRONMENT ./helm/pci-app \
    --namespace $NAMESPACE \
    --create-namespace \
    --set global.namespace=$NAMESPACE \
    --set frontend.image.repository=$ACR_NAME.azurecr.io/pci-frontend \
    --set frontend.image.tag=$TAG \
    --set backend.image.repository=$ACR_NAME.azurecr.io/pci-backend \
    --set backend.image.tag=$TAG \
    --wait --timeout=10m

echo "✅ Deployment completed successfully!"

# Show deployment status
echo "📊 Deployment Status:"
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE
kubectl get ingress -n $NAMESPACE

echo ""
echo "🔍 To view logs:"
echo "kubectl logs -f deployment/pci-app-$ENVIRONMENT-backend -n $NAMESPACE"
echo "kubectl logs -f deployment/pci-app-$ENVIRONMENT-frontend -n $NAMESPACE"
