# Issues Faced During Implementation

## Infrastructure

### 1. Node Group Pod Capacity

- **Problem**: After deploying the monitoring stack (Prometheus + Grafana) alongside the microservices, pods started failing to schedule with "too many pods" errors.

- **Root Cause**: Was using `t3.medium` (2 vCPU, 4 GB RAM) which supports a max of 17 pods per node. The default namespace already consumes some slots, and with 7 application pods + monitoring + ArgoCD, the limit was easily breached.

- **Solution**: Upgraded the instance type to `m7i-flex.large` which supports significantly more pods per node. This resolved the scheduling issue immediately.

### 2. EBS Volume Permission Issue

- **Problem**: The EBS CSI driver was failing to attach persistent volumes to the PostgreSQL StatefulSet. Pods were stuck in `Pending` state.

- **Root Cause**: EKS v1.32+ requires IRSA (IAM Roles for Service Accounts) for the EBS CSI driver. Standard node-level IAM roles alone are no longer sufficient — the CSI controller runs as a service account and needs its own role bound via OIDC.

- **Solution**: Configured an OIDC provider in the EKS Terraform module and attached an IRSA policy specifically for the `ebs-csi-controller-sa` service account.

---

## Database

### 1. StatefulSet Init Script Silently Skipped

- **Problem**: PostgreSQL StatefulSet had a full DB dump attached as an init script, but on first deploy the database was empty. The pod itself ran fine — no errors — but the `products_db` didn't exist, causing the product-service to return empty responses.

- **Root Cause**: Fresh EBS volumes in AWS come with a `lost+found` directory. PostgreSQL's entrypoint script checks if the data directory is empty before running init scripts — it detected `lost+found`, considered the directory non-empty, and silently skipped initialization entirely.

- **Solution**: Created a separate Kubernetes Job (`restore-job.yml`) that runs `psql` commands to create all 4 databases and load the schema. The Job is applied after the PostgreSQL pod is `Ready 1/1`, ensuring the data directory issue is bypassed.

---

## CI/CD Pipeline

### 1. GitHub Actions Failing to Push Manifest Updates

- **Problem**: The CI pipeline built and pushed all 7 Docker images successfully, but the `update-manifests` job failed silently — no manifest changes were committed back to the repo.

- **Root Cause**: By default, `GITHUB_TOKEN` in GitHub Actions has **read-only** permissions for repository contents. The `git push` in the pipeline was rejected because the token didn't have write access.

- **Solution**: Changed repository settings → **Actions** → **General** → **Workflow permissions** → selected **Read and write permissions**. The pipeline was then able to commit and push the updated image tags.

### 2. Image Tags Hardcoded After First Pipeline Run

- **Problem**: After the first successful pipeline run, the Kubernetes manifests in `gitops/k8s/` had real AWS Account IDs and commit SHAs hardcoded in them. This was a security concern for pushing to a public GitHub repo.

- **Root Cause**: The `sed` command in the pipeline replaces `<AWS_ACCOUNT_ID>` placeholders with actual values and commits the result. Once the real account ID is in the file, subsequent pushes expose it.

- **Solution**: Before pushing to GitHub, ran a script to scrub all 12-digit AWS account IDs from the manifests and replace them back with `<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com` placeholders. The pipeline handles the actual replacement at runtime.

---

## Logging

### 1. Fluent Bit "Unauthorized" & "No Credentials" Errors

- **Problem**: Fluent Bit DaemonSet was deployed and running, but no logs appeared in CloudWatch. The Fluent Bit pods themselves were logging "unauthorized" and "no credentials found" errors.

- **Root Cause**: Two issues stacked together:
  1. The `CloudWatchAgentServerPolicy` was not attached to the EKS node IAM role — so the pods had no CloudWatch write permissions.
  2. The pods couldn't reach the EC2 Instance Metadata Service (IMDS) to pick up instance credentials, because EKS network isolation blocked metadata access by default.

- **Solution**: 
  1. Attached `CloudWatchAgentServerPolicy` to the EKS node group IAM role.
  2. Added `hostNetwork: true` to the Fluent Bit DaemonSet spec to allow direct metadata service access.

---

## Monitoring

### 1. Application Metrics Not Showing in Grafana

- **Problem**: Cluster-level metrics (node CPU, memory, pod counts) were working fine in Grafana, but the custom application metrics (HTTP request rates, response times, error counts) from the boutique microservices were completely missing.

- **Root Cause**: The ServiceMonitor was deployed but Prometheus wasn't actually scraping the application pods. The `matchLabels` on the ServiceMonitor didn't align with the service labels, and the gateway service wasn't exposing the `/metrics` port in its Service spec.

- **Solution**: Updated the ServiceMonitor `matchLabels` to target the correct app labels, and added the metrics port to the gateway Service definition. After restarting the Prometheus pod, all application-level metrics started flowing into Grafana dashboards.
