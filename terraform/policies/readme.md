# AWS Organizations Governance Policies

This repository contains foundational governance policies for a secure, compliant, and well-architected multi-account AWS environment. The policies enforce **least privilege**, **regional compliance**, **tagging standards**, and **organizational control** using native AWS Organizations features.

---

## 📁 Policy Components

### 1. **`scp-deny-root-user.json`**  
**Type**: Service Control Policy (SCP)  
**Purpose**: Prevents the root user of any member account from performing actions.  
**Key Rule**:  
```json
"Condition": {
  "StringLike": {
    "aws:PrincipalArn": "arn:aws:iam::*:root"
  }
}
```
> ✅ **Best Practice**: Root credentials should never be used in member accounts. This SCP enforces that principle organization-wide.

---

### 2. **`iam-organizations-admin.json`**  
**Type**: IAM Policy  
**Purpose**: Grants full permissions to manage AWS Organizations and request service quota increases.  
**Permissions Include**:
- `organizations:*`
- `servicequotas:ListRequestedServiceQuotas`
- `servicequotas:RequestServiceQuotaIncrease`
- Required `iam:CreateServiceLinkedRole` for Organizations  

> 🔐 **Apply To**: Administrative IAM users/roles in the **management account only** (e.g., `arn:aws:iam::797923187401:user/Kaseh`).

---

### 3. **`scp-region-lock-us-east-1.json`**  
**Type**: Service Control Policy (SCP)  
**Purpose**: Restricts resource creation to **`us-east-1`** only.  
**Exceptions**: Global services (`iam`, `sts`, `organizations`, `support`) are allowed in all regions.  
**Use Case**: Enforce single-region deployment for cost control, compliance, or simplicity.

> 🌍 **Customize**: Modify the `"aws:RequestedRegion"` list if multi-region support is needed later.

---

### 4. **`tag-policy.json`**  
**Type**: AWS Organizations Tag Policy  
**Purpose**: Enforces mandatory tagging for cost allocation and resource governance.  
**Requirements**:
- `Environment` tag with value in: `["Production", "Staging", "Development", "Sandbox"]`
- `Owner` tag (value unrestricted but required)

> 💡 **Integration**: Enables accurate cost reporting in **AWS Cost Explorer** and automated compliance checks.

---

## 🚀 Deployment Guide

### Prerequisites
- AWS CLI configured with **management account** admin credentials
- AWS Organizations enabled
- Target OUs created (e.g., `Production`, `Sandbox`)

### Steps

#### 1. **Create & Attach SCPs**
```bash
# Create SCPs
aws organizations create-policy --name "DenyRootUser" --type SERVICE_CONTROL_POLICY --content file://scp-deny-root-user.json
aws organizations create-policy --name "RegionLock-us-east-1" --type SERVICE_CONTROL_POLICY --content file://scp-region-lock-us-east-1.json

# Attach to Root or specific OUs
aws organizations attach-policy --policy-id p-xxxxxx --target-id ou-xxxxxx
```

#### 2. **Apply IAM Policy**
Attach `iam-organizations-admin.json` to your administrative IAM user/role in the **management account** via:
- AWS Console → IAM → Users → `Kaseh` → Add permissions
- Or via Terraform/IaC

#### 3. **Enable Tag Policy**
1. Go to **AWS Organizations → Policies → Tag policies**
2. Click **Create policy**, paste `tag-policy.json`
3. Attach to Root or target OUs

---

## 🏷️ Tagging Standard

| Tag             | Allowed Values                                  | Required |
|-----------------|------------------------------------------------|----------|
| `Environment`   | `Production`, `Staging`, `Development`, `Sandbox` | ✅ Yes   |
| `Owner`         | Any (e.g., team email)                         | ✅ Yes   |

> ⚠️ Resources without these tags may be non-compliant or excluded from cost reports.

---

## 🔒 Security & Compliance Benefits

- **Eliminates root user risk** in member accounts
- **Enforces regional boundaries** to prevent accidental cross-region costs
- **Standardizes tagging** for FinOps and security audits
- **Centralized control** via AWS Organizations

---

## 📚 References

- [AWS SCP Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
- [Tag Policies Documentation](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies.html)
- [Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

> **Note**: Replace placeholder values (e.g., account IDs, emails) before production use. Test policies in a sandbox OU first.
