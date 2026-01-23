# FinTech Global Platform – AWS Infrastructure (Terraform)

This repository defines a **secure, scalable, and production-ready AWS infrastructure** for the **FinTech Global** platform using Terraform. It implements a multi-tier architecture with EKS, Aurora PostgreSQL, Redis, DynamoDB, S3 data lake, cost governance, and secrets management—all aligned with AWS Well-Architected best practices.

---

## 🏗️ Architecture Overview
<img width="428" height="623" alt="image" src="https://github.com/user-attachments/assets/7862e6a5-2ebb-44c7-93a9-9abcc75e3546" />


### Core Components

| Layer                | Services Used                                                                 |
|----------------------|-------------------------------------------------------------------------------|
| **Compute**          | Amazon EKS (Fargate + Managed Nodes), Horizontal Pod Autoscaler               |
| **Database**         | Aurora PostgreSQL (Writer + Reader + Auto Scaling), DynamoDB (Sessions)       |
| **Caching**          | Amazon ElastiCache (Redis Cluster, Auth-enabled, Encrypted)                   |
| **Storage**          | S3 Data Lake (Versioned, Encrypted, Lifecycle-managed), S3 Logs Bucket        |
| **Security**         | KMS (Data Encryption), Secrets Manager, IAM Roles, VPC Endpoints              |
| **Networking**       | VPC (Public/Private Subnets), NAT Gateways, Security Groups, Route Tables     |
| **Observability**    | CloudWatch Dashboard, RDS Performance Insights, Enhanced Monitoring           |
| **Cost Governance**  | Budgets, Cost Anomaly Detection, SNS Alerts, CUR (planned)                    |

---

## 📁 Module Structure

```
.
├── vpc/                  # Highly available VPC with public/private tiers
├── eks/                  # EKS cluster with Fargate & managed node groups
├── database/             # Aurora PostgreSQL cluster + auto-scaling read replicas
├── cache/                # Redis replication group with auth & encryption
├── storage/              # S3 data lake with lifecycle, versioning, and logging
├── secrets/              # Secrets Manager for DB, Redis, API keys, and encryption keys
├── monitoring/           # CloudWatch dashboard and HPA for Kubernetes
└── cost-governance/      # Budgets, anomaly detection, SNS alerts
```

---

## 🔐 Security Highlights

- **All data encrypted at rest** using customer-managed KMS key (`alias/fintech-data-key`)
- **Secrets stored securely** in AWS Secrets Manager (DB credentials, Redis auth, API keys)
- **No public access** to databases or caches—only allowed from EKS security groups
- **VPC endpoints** for S3, DynamoDB, ECR, Secrets Manager, and SSM (no internet required)
- **Root user blocked** via SCP (not shown here but recommended in Org)
- **Pods run with least privilege** via IAM roles for service accounts (IRSA-style via pod role)

---

## 💰 Cost Governance

### 1. **Monthly Budget**
- Total spend limit: **$5,000/month** (configurable)
- Email alerts at **80%** and **100%** usage

### 2. **Per-Service Budgets**
| Service                                      | Limit ($) |
|----------------------------------------------|----------|
| Amazon Elastic Container Service for Kubernetes | 2,000    |
| Amazon Relational Database Service           | 1,500    |
| Amazon ElastiCache                           | 500      |
| Amazon DynamoDB                              | 300      |
| Amazon S3                                    | 200      |

### 3. **Anomaly Detection**
- Immediate SNS alert if **unexpected cost spike ≥ $20**
- Monitors per linked account

### 4. **CloudWatch Dashboard**
- Real-time **Estimated Charges**
- **Budget vs Actual** tracking

> ✅ *Note: Cost and Usage Report (CUR) is prepared but commented out—uncomment to enable Athena integration.*

---

## 🚀 Deployment

### Prerequisites
- AWS CLI configured with admin credentials
- Terraform v1.6+
- Variables defined in `terraform.tfvars`:
  ```hcl
  project_name = "fintechglobal"
  region       = "us-east-1"
  account_id   = "797923187401"
  alert_email  = "team-platform@yourcompany.com"
  monthly_budget_limit = "5000"
  ```

### Steps
```bash
# Initialize
terraform init

# Plan
terraform plan -var-file="terraform.tfvars"

# Apply
terraform apply -var-file="terraform.tfvars"
```

### Outputs
After apply, you’ll get:
- `cluster_endpoint`: EKS API endpoint
- `kubeconfig`: Ready-to-use kubeconfig for `kubectl`
- `vpc_id`, subnet IDs, etc.

---

## 🧪 Post-Deployment Tasks

1. **Configure kubectl**:
   ```bash
   terraform output -raw kubeconfig > ~/.kube/config-fintech
   export KUBECONFIG=~/.kube/config-fintech
   kubectl get nodes
   ```

2. **Deploy Application** to `fintech-prod` namespace

3. **Test Alerts**:
   - Trigger a budget notification by increasing test spend
   - Confirm email delivery

4. **Enable CUR** (optional):
   - Uncomment `aws_cur_report_definition` block
   - Set up Athena for advanced cost analytics

---

## 📚 References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Aurora Auto Scaling](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Integrating.AutoScaling.html)
- [S3 Data Lake Patterns](https://aws.amazon.com/solutions/implementations/data-lake-solution/)

---

> **⚠️ Warning**: This setup uses `skip_final_snapshot = true` and `deletion_protection = false` for development convenience. **In production, enable deletion protection and final snapshots.**

> **🔐 Reminder**: Rotate secrets regularly. Use AWS Secrets Manager rotation (Lambda) for long-term security.

---

**Maintained by**: Mohamed Mahmoud Desouky  
**Project**: FinTech Global Platform  
**Environment**: Production (US East 1)
