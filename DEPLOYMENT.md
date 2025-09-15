# PCI Application Deployment Guide

This document provides comprehensive instructions for deploying the PCI (Paralympic Committee of India) application to Azure Kubernetes Service (AKS).

## Architecture Overview

The application consists of:
- **Frontend**: Next.js application (React)
- **Backend**: Express.js API with TypeScript
- **Database**: PostgreSQL
- **Infrastructure**: Azure Kubernetes Service (AKS)

## Prerequisites

### Azure Resources
1. **Azure Container Registry (ACR)**
2. **Azure Kubernetes Service (AKS) cluster**
3. **Static IP address** (for ingress)
4. **Domain name** (optional, for custom domain)

### Local Development Tools
- Docker Desktop
- Azure CLI
- kubectl
- Helm 3.x
- Node.js 18+
- pnpm

## Initial Azure Setup

### 1. Create Resource Group
```bash
az group create --name pci-rg --location eastus
```

### 2. Create Azure Container Registry
```bash
az acr create --resource-group pci-rg --name pciregistry --sku Basic
```

### 3. Create AKS Cluster
```bash
az aks create \
  --resource-group pci-rg \
  --name pci-aks-cluster \
  --node-count 3 \
  --enable-addons monitoring \
  --attach-acr pciregistry \
  --generate-ssh-keys
```

### 4. Get AKS Credentials
```bash
az aks get-credentials --resource-group pci-rg --name pci-aks-cluster
```

### 5. Create Static IP (Optional)
```bash
az network public-ip create \
  --resource-group MC_pci-rg_pci-aks-cluster_eastus \
  --name pci-static-ip \
  --sku Standard \
  --allocation-method static
```

## Local Development

### Using Docker Compose
```bash
# Navigate to backend directory
cd PCI-backend

# Start all services (database, backend, frontend)
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Manual Development Setup
```bash
# Start PostgreSQL
cd PCI-backend
docker-compose up -d db

# Start Backend
pnpm install
pnpm run dev

# Start Frontend (in new terminal)
cd PCI
pnpm install
pnpm run dev
```

## Production Deployment

### Method 1: Using Helm Charts (Recommended)

#### 1. Update Configuration
Edit `helm/pci-app/values.yaml`:
```yaml
# Update container registry
backend:
  image:
    repository: "pciregistry.azurecr.io/pci-backend"

frontend:
  image:
    repository: "pciregistry.azurecr.io/pci-frontend"

# Update domain
ingress:
  hosts:
    - host: your-actual-domain.com
```

#### 2. Build and Push Images
```bash
# Build and push backend
cd PCI-backend
az acr build --registry pciregistry --image pci-backend:latest .

# Build and push frontend
cd ../PCI
az acr build --registry pciregistry --image pci-frontend:latest .
```

#### 3. Install Required Components
```bash
# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.loadBalancerIP=YOUR_STATIC_IP

# Install cert-manager (for SSL)
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true
```

#### 4. Deploy Application
```bash
helm install pci-app ./helm/pci-app \
  --namespace pci-app \
  --create-namespace \
  --set frontend.image.repository=pciregistry.azurecr.io/pci-frontend \
  --set frontend.image.tag=latest \
  --set backend.image.repository=pciregistry.azurecr.io/pci-backend \
  --set backend.image.tag=latest \
  --set ingress.hosts[0].host=your-domain.com \
  --set database.auth.password="your-secure-password"
```

### Method 2: Using Raw Kubernetes Manifests

#### 1. Update Image Names
Edit the following files to update container registry names:
- `k8s/backend-deployment.yaml`
- `k8s/frontend-deployment.yaml`

#### 2. Update Secrets
```bash
# Encode your database password
echo -n "your-secure-password" | base64

# Update k8s/secret.yaml with the encoded password
```

#### 3. Apply Manifests
```bash
kubectl apply -f k8s/
```

## CI/CD Setup

### 1. Create Azure Service Principal
```bash
az ad sp create-for-rbac --name "pci-github-actions" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/pci-rg \
  --sdk-auth
```

### 2. Configure GitHub Secrets
Add the following secrets to your GitHub repository:

- `AZURE_CREDENTIALS`: Output from service principal creation
- `DB_PASSWORD`: Secure database password
- `DOMAIN_NAME`: Your production domain
- `PREVIEW_DOMAIN`: Domain for PR previews
- `STATIC_IP`: Your Azure static IP address

### 3. Update Workflow Variables
Edit `.github/workflows/ci-cd.yml` and `.github/workflows/pr-preview.yml`:
```yaml
env:
  AZURE_CONTAINER_REGISTRY: pciregistry  # Your ACR name
  CLUSTER_NAME: pci-aks-cluster         # Your AKS cluster name
  CLUSTER_RESOURCE_GROUP: pci-rg        # Your resource group name
```

## Environment Variables

### Frontend Environment Variables
- `NODE_ENV`: production/development
- `NEXT_PUBLIC_API_URL`: Backend API URL
- `NEXT_TELEMETRY_DISABLED`: "1"
- `SKIP_ENV_VALIDATION`: "1"

### Backend Environment Variables
- `NODE_ENV`: production/development
- `PORT`: 3001
- `DB_URL`: PostgreSQL connection string

## Database Migrations

### Manual Migration
```bash
# Connect to backend pod
kubectl exec -it deployment/pci-app-backend -n pci-app -- /bin/sh

# Run migrations
npm run drizzle:migrate
```

### Automatic Migration
Migrations run automatically when the backend starts via the Docker CMD.

## Monitoring and Logging

### View Logs
```bash
# All pods in namespace
kubectl logs -f -l app.kubernetes.io/instance=pci-app -n pci-app

# Specific service
kubectl logs -f deployment/pci-app-backend -n pci-app
kubectl logs -f deployment/pci-app-frontend -n pci-app
```

### Health Checks
- Backend: `http://your-domain.com/api/health`
- Frontend: `http://your-domain.com/`

### Scaling
```bash
# Scale frontend
kubectl scale deployment pci-app-frontend --replicas=5 -n pci-app

# Scale backend
kubectl scale deployment pci-app-backend --replicas=3 -n pci-app
```

## Troubleshooting

### Common Issues

#### 1. ImagePullBackOff Error
```bash
# Check if ACR is attached to AKS
az aks check-acr --resource-group pci-rg --name pci-aks-cluster --acr pciregistry

# If not attached, attach it
az aks update --resource-group pci-rg --name pci-aks-cluster --attach-acr pciregistry
```

#### 2. Database Connection Issues
```bash
# Check database pod status
kubectl get pods -n pci-app -l app.kubernetes.io/component=database

# Check database logs
kubectl logs deployment/pci-app-postgres -n pci-app

# Test connectivity from backend pod
kubectl exec -it deployment/pci-app-backend -n pci-app -- pg_isready -h postgres-service -p 5432
```

#### 3. Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress status
kubectl get ingress -n pci-app

# Check external IP
kubectl get service -n ingress-nginx
```

### Debug Commands
```bash
# Describe problematic resources
kubectl describe pod <pod-name> -n pci-app
kubectl describe service <service-name> -n pci-app
kubectl describe ingress <ingress-name> -n pci-app

# Get events
kubectl get events -n pci-app --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods -n pci-app
```

## Security Considerations

1. **Secrets Management**: Use Azure Key Vault for production secrets
2. **Network Policies**: Implement Kubernetes network policies
3. **RBAC**: Configure proper role-based access control
4. **Image Scanning**: Enable vulnerability scanning in ACR
5. **SSL/TLS**: Use cert-manager for automatic certificate management

## Backup and Disaster Recovery

### Database Backup
```bash
# Create backup job
kubectl create job --from=cronjob/postgres-backup postgres-backup-manual -n pci-app

# Manual backup
kubectl exec deployment/pci-app-postgres -n pci-app -- pg_dump -U pci pci > backup.sql
```

### Application Backup
Use Velero for cluster-level backups:
```bash
# Install Velero
velero install --provider azure --plugins velero/velero-plugin-for-microsoft-azure

# Create backup
velero backup create pci-app-backup --include-namespaces pci-app
```

## Performance Optimization

1. **Resource Limits**: Set appropriate CPU/memory limits
2. **Horizontal Pod Autoscaler**: Enable HPA for automatic scaling
3. **CDN**: Use Azure CDN for static assets
4. **Caching**: Implement Redis for session management
5. **Database**: Use Azure Database for PostgreSQL for managed service

## Cost Optimization

1. **Node Pools**: Use appropriate node sizes
2. **Spot Instances**: Use Azure Spot VMs for non-critical workloads
3. **Auto-scaling**: Configure cluster autoscaler
4. **Resource Quotas**: Set namespace resource quotas
5. **Monitoring**: Use Azure Cost Management

This completes the deployment guide for the PCI application on Azure Kubernetes Service.
