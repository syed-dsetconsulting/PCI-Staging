# PCI Application Containerization

This document explains the containerization setup for the PCI (Paralympic Committee of India) application and deployment to Azure Kubernetes Service.

## 📁 Project Structure

```
PCI-New-Combined/
├── PCI/                          # Frontend (Next.js)
│   ├── Dockerfile               # Frontend container configuration
│   ├── .dockerignore           # Files to exclude from Docker build
│   └── next.config.js          # Updated with standalone output
├── PCI-backend/                 # Backend (Express.js)
│   ├── Dockerfile              # Backend container configuration
│   ├── .dockerignore           # Files to exclude from Docker build
│   └── docker-compose.yml      # Updated for full stack
├── k8s/                         # Kubernetes manifests
│   ├── namespace.yaml          # Namespace definition
│   ├── configmap.yaml          # Configuration
│   ├── secret.yaml             # Secrets (passwords, etc.)
│   ├── postgres-*.yaml         # Database components
│   ├── backend-*.yaml          # Backend service components
│   ├── frontend-*.yaml         # Frontend service components
│   └── ingress.yaml            # Load balancer configuration
├── helm/                        # Helm charts for easier deployment
│   └── pci-app/
│       ├── Chart.yaml          # Helm chart metadata
│       ├── values.yaml         # Default configuration
│       └── templates/          # Kubernetes template files
├── .github/workflows/           # CI/CD pipelines
│   ├── ci-cd.yml              # Main production pipeline
│   └── pr-preview.yml         # PR preview environments
├── scripts/                     # Deployment scripts
│   ├── build-and-push.sh      # Build and push images
│   ├── deploy.sh              # Deploy to Kubernetes
│   └── local-dev.sh           # Local development
├── DEPLOYMENT.md               # Comprehensive deployment guide
└── CONTAINERIZATION.md        # This file
```

## 🐳 Docker Configuration

### Frontend (Next.js)
- **Base Image**: `node:18-alpine`
- **Multi-stage build**: Dependencies → Build → Runtime
- **Standalone output**: Optimized for containers
- **Port**: 3000

### Backend (Express.js)
- **Base Image**: `node:18-alpine`
- **Multi-stage build**: Dependencies → Build → Runtime
- **TypeScript compilation**: Source → JavaScript
- **Port**: 3001

### Database
- **Image**: `postgres:16.1`
- **Persistent Storage**: Azure Managed Disk
- **Port**: 5432

## 🚀 Quick Start

### Local Development
```bash
# Start all services with Docker Compose
cd PCI-backend
docker-compose up -d

# Access the application
# Frontend: http://localhost:3000
# Backend: http://localhost:3001
# Database Admin: http://localhost:8000
```

### Production Deployment
```bash
# 1. Build and push images
./scripts/build-and-push.sh your-acr-name latest

# 2. Deploy to AKS
./scripts/deploy.sh production your-acr-name latest
```

## ☁️ Azure Kubernetes Service Deployment

### Architecture
```
Internet → Azure Load Balancer → NGINX Ingress → Frontend/Backend Pods → PostgreSQL Pod
```

### Components
- **Frontend Pods**: 2 replicas (scalable)
- **Backend Pods**: 2 replicas (scalable)
- **Database Pod**: 1 replica with persistent storage
- **Ingress Controller**: NGINX for load balancing
- **SSL/TLS**: cert-manager for automatic certificates

### Networking
- **Frontend Service**: ClusterIP on port 3000
- **Backend Service**: ClusterIP on port 3001
- **Database Service**: ClusterIP on port 5432
- **Ingress**: Routes traffic based on path (`/api` → backend, `/` → frontend)

## 🔧 Configuration Management

### Environment Variables
**Frontend:**
- `NODE_ENV`: production/development
- `NEXT_PUBLIC_API_URL`: Backend API URL
- `NEXT_TELEMETRY_DISABLED`: "1"

**Backend:**
- `NODE_ENV`: production/development
- `PORT`: 3001
- `DB_URL`: PostgreSQL connection string

### Secrets Management
- Database passwords stored in Kubernetes Secrets
- Base64 encoded in manifests
- Can be integrated with Azure Key Vault

### Configuration Maps
- Non-sensitive configuration stored in ConfigMaps
- Environment-specific values
- Easy to update without rebuilding images

## 🔄 CI/CD Pipeline

### GitHub Actions Workflows

#### Main Pipeline (`ci-cd.yml`)
1. **Test Stage**: Run tests for both frontend and backend
2. **Build Stage**: Build and push Docker images to ACR
3. **Deploy Stage**: Deploy to AKS using Helm

#### PR Preview (`pr-preview.yml`)
1. **Build**: Create PR-specific images
2. **Deploy**: Create isolated preview environment
3. **Comment**: Add preview URL to PR
4. **Cleanup**: Remove environment when PR is closed

### Triggers
- **Production Deploy**: Push to `main` branch
- **PR Preview**: Pull request opened/updated
- **Manual**: Workflow dispatch

## 📊 Monitoring & Logging

### Health Checks
- **Frontend**: HTTP GET `/`
- **Backend**: HTTP GET `/api/health`
- **Database**: `pg_isready` command

### Logging
```bash
# View all application logs
kubectl logs -f -l app.kubernetes.io/instance=pci-app -n pci-app

# View specific service logs
kubectl logs -f deployment/pci-app-backend -n pci-app
kubectl logs -f deployment/pci-app-frontend -n pci-app
```

### Metrics
- Resource usage monitoring
- Pod restart counts
- Response time metrics

## 🔒 Security Features

### Container Security
- Non-root user in containers
- Security contexts applied
- Minimal base images (Alpine Linux)

### Kubernetes Security
- Network policies for pod communication
- RBAC for access control
- Secrets for sensitive data

### Network Security
- TLS/SSL termination at ingress
- Internal cluster communication
- Database access restricted to backend only

## 📈 Scaling & Performance

### Horizontal Pod Autoscaler
```yaml
# Enable autoscaling in values.yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Manual Scaling
```bash
# Scale frontend
kubectl scale deployment pci-app-frontend --replicas=5 -n pci-app

# Scale backend
kubectl scale deployment pci-app-backend --replicas=3 -n pci-app
```

### Resource Limits
- CPU requests/limits: 250m/500m
- Memory requests/limits: 256Mi/512Mi
- Adjustable via Helm values

## 🛠️ Development Workflow

### Local Development
1. Use Docker Compose for full stack development
2. Hot reload enabled for both frontend and backend
3. Persistent database data

### Testing
1. Unit tests run in CI pipeline
2. Integration tests with test containers
3. E2E tests in preview environments

### Deployment
1. Feature branches → PR preview
2. Merge to main → Production deployment
3. Rollback capability via Helm

## 💰 Cost Optimization

### Infrastructure
- Use appropriate node sizes
- Enable cluster autoscaler
- Use Azure Spot VMs for development

### Application
- Resource requests/limits optimization
- Image size optimization
- Persistent volume sizing

## 🔧 Troubleshooting

### Common Issues

#### Container Image Issues
```bash
# Check if images are accessible
kubectl describe pod <pod-name> -n pci-app

# Verify ACR integration
az aks check-acr --resource-group pci-rg --name pci-aks-cluster --acr your-acr
```

#### Database Connection Issues
```bash
# Test database connectivity
kubectl exec -it deployment/pci-app-backend -n pci-app -- pg_isready -h postgres-service -p 5432

# Check database logs
kubectl logs deployment/pci-app-postgres -n pci-app
```

#### Ingress Issues
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Verify ingress configuration
kubectl describe ingress pci-app-ingress -n pci-app
```

### Debug Commands
```bash
# Get events
kubectl get events -n pci-app --sort-by=.metadata.creationTimestamp

# Resource usage
kubectl top nodes
kubectl top pods -n pci-app

# Service endpoints
kubectl get endpoints -n pci-app
```

## 📚 Additional Resources

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Detailed deployment instructions
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)

## ✅ Next Steps

1. **Set up Azure resources** (ACR, AKS)
2. **Configure GitHub secrets** for CI/CD
3. **Update domain names** in configuration
4. **Run deployment scripts**
5. **Monitor application** health

This containerization setup provides a robust, scalable, and maintainable deployment solution for the PCI application on Azure Kubernetes Service.
