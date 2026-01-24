# Bookstore Application – Kubernetes Deployment

This README describes the Kubernetes manifests used to deploy the Bookstore application on Minikube (or any standard Kubernetes cluster). The configuration uses Kustomize, follows security best practices, and includes autoscaling, networking, and reliability features.

All resources are defined declaratively using native Kubernetes YAML.

---

## Directory Structure
```
k8s/
├── base/                     # Core application manifests
├── overlays/prod/            # Production overlay (currently minimal)
├── auto-scaling/             # HPA and PodDisruptionBudgets
└── security/                 # Network policies, secrets, quotas
```
---

## Base Manifests (k8s/base)

These files define the core application components:

| File                          | Purpose |
|-------------------------------|---------|
| namespace.yaml                | Dedicated namespace for the app |
| pv.yaml                       | PersistentVolume (uses hostPath for Minikube) |
| pvc.yaml                      | PersistentVolumeClaim for MySQL |
| mysql-init-configmap.yaml     | ConfigMap containing SQL init script |
| init.sql                      | Database schema and sample data |
| database.yaml                 | MySQL Deployment |
| database-service.yaml         | ClusterIP Service for MySQL |
| redis.yaml                    | Redis Deployment |
| redis-service.yaml            | ClusterIP Service for Redis |
| backend.yaml                  | Node.js backend Deployment |
| backend-service.yaml          | ClusterIP Service for backend |
| frontend-deployment.yaml      | Nginx frontend Deployment |
| frontend-service.yaml         | ClusterIP Service for frontend |
| ingress-frontend.yaml         | Ingress resource with TLS termination |
| bookstore-tls.yaml            | Secret containing TLS certificate and key |
| tls.crt                       | Self-signed TLS certificate |
| tls.key                       | TLS private key |
| kustomization.yaml            | Kustomize entrypoint for base |

> Note: TLS uses self-signed certs for local testing. Replace in production.

---

## Security Layer (k8s/security)

Enforces least-privilege and isolation:

| File                              | Purpose |
|-----------------------------------|---------|
| backend-configmap.yaml            | Backend configuration (e.g., API settings) |
| backend-secret.yaml               | Sensitive data (e.g., database password, API key) |
| database-configmap.yaml           | MySQL config (e.g., charset, max connections) |
| database-secret.yaml              | MySQL root/user passwords |
| frontend-network-policy.yaml      | Restricts traffic to frontend (only from Ingress) |
| database-network-policy.yaml      | Allows DB access only from backend |
| redis-networkpolicy.yaml          | Allows Redis access only from backend |
| resource-quotas.yaml              | Enforces CPU/memory limits at namespace level |
| kustomization.yaml                | Kustomize entrypoint for security layer |

### Network Policy Summary

- Frontend: Accepts traffic only from Ingress controller.
- Backend: Can talk to Redis and MySQL; no external inbound.
- Redis & MySQL: Only accept connections from Backend pods.
- Default deny-all is implied by explicit allow rules.

---

## Autoscaling & Reliability (k8s/auto-scaling)

Ensures availability and responsiveness under load:

| File                   | Purpose |
|------------------------|---------|
| backend-HPA.yaml       | Horizontal Pod Autoscaler for backend (CPU-based) |
| frontend-HPA.yaml      | HPA for frontend (memory-based) |
| pdb-backend.yaml       | PodDisruptionBudget: min 1 backend pod available |
| pdb-frontend.yaml      | PDB: min 1 frontend pod available |
| pdb-database.yaml      | PDB: prevents eviction of MySQL pod |
| pdb-redis.yaml         | PDB: prevents eviction of Redis pod |
| kustomization.yaml     | Kustomize entrypoint for autoscaling |

---

## Deployment Instructions

### 1. Start Minikube (if using locally)

```bash
minikube start --cpus=4 --memory=6g
minikube addons enable ingress
```
### 2. Apply Kubernetes Resources
```bash
# Deploy core app:-
kubectl apply -k k8s/base

# Apply security controls:-
kubectl apply -k k8s/security

# Apply autoscaling & reliability:-
kubectl apply -k k8s/auto-scaling

```
#### To apply it all in one step, We use kustomization file
```bash
kubectl apply -k k8s/overlays/prod/
```
### 3. Access the Application
```bash
# Get the Ingress IP
echo "Visit: https://$(minikube ip)"
```
## 🔍 Verification Commands
```bash
# Check all pods
kubectl get pods -n bookstore

# View network policies
kubectl get networkpolicy -n bookstore

# Check autoscaling status
kubectl get hpa -n bookstore

# Verify PDBs
kubectl get pdb -n bookstore

# Test connectivity (from backend pod)
kubectl exec deploy/backend -n bookstore -- nc -zv mysql 3306
kubectl exec deploy/backend -n bookstore -- nc -zv redis 6379
```
## 🧹 Cleanup
```bash
kubectl delete -k k8s/auto-scaling
kubectl delete -k k8s/security
kubectl delete -k k8s/base
```
