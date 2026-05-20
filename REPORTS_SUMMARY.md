# Project Troubleshooting & Resolution Summary

This document provides a detailed overview of the issues encountered during the deployment of the Boutique Microservices platform on AWS EKS, the surgical fixes applied, and the best practices implemented to ensure a robust GitOps workflow.

## 🚀 Overview
The project involves a microservices architecture (Node.js/TypeScript) deployed on EKS using Argo CD for GitOps and GitHub Actions for CI/CD.

---

## 🛠 Issues Encountered & Solutions

### 1. Image Pull Failures (`InvalidImageName` / `ImagePullBackOff`)
**Error:** Pods failed to start because the Kubernetes manifests contained a literal `<AWS_ACCOUNT_ID>` placeholder.
*   **Root Cause:** The manifests were committed with placeholders that were never replaced by the CI pipeline, causing Kubernetes to attempt pulling invalid image URIs.
*   **Fix:** 
    *   Manually updated all manifests in `gitops/k8s/` with the actual AWS Account ID (`914194816156`).
    *   Updated the image tags to point to a verified existing ECR image revision (`ff268e59`).

### 2. CI Pipeline Failures (Tag Updates Not Reflecting)
**Error:** New code pushes triggered the pipeline, but the Kubernetes manifests in the repository were not being updated with the new image tags.
*   **Root Cause:** The `sed` command in the GitHub Actions workflow used a strict regex pattern that expected the *exact* current Account ID to be present. If a placeholder was used, the match failed silently.
*   **Fix:** 
    *   **Robust Regex:** Refactored the `sed` command to match based on the `image:` key and the service name (`SERVICE`), making it independent of the specific Account ID or current tag.
    *   **Logging:** Added debug echo statements to the pipeline to provide visibility into which manifests are being updated during each run.

### 3. Database Connection Errors (`products_db` does not exist)
**Error:** Even after images were fixed, services like `product-service` were stuck in a `CrashLoopBackOff`.
*   **Root Cause:** The PostgreSQL instance was running, but the specific databases and schemas required by the microservices (e.g., `products_db`, `auth_db`) had not been initialized.
*   **Fix:** 
    *   Identified and executed the `boutique-db-restore` Kubernetes Job.
    *   Temporarily scaled down non-critical services to accommodate the resource-intensive restore process on a single-node cluster.

### 4. Client-Side Connectivity (Products Not Visible)
**Error:** The frontend was running but showing zero products.
*   **Root Cause:** The frontend code in the browser was trying to reach `http://gateway:3001`, which is an internal cluster DNS name unreachable from the user's local machine.
*   **Fix:** 
    *   Implemented a local workaround using `kubectl port-forward` for the gateway service.
    *   Updated the local `/etc/hosts` file to map `gateway` to `127.0.0.1`.

---

## 🏆 Best Practices Implemented

### 🛡️ GitOps & Argo CD
*   **Automated Sync & Self-Healing:** Enabled `selfHeal` and `prune` in the Argo CD Application manifest. This ensures that accidental manual changes to the cluster are automatically reverted to the state defined in Git.
*   **Namespace Isolation:** Used dedicated namespaces (`boutique`, `argocd`, `monitoring`) to separate application logic from infrastructure management.

### 🤖 CI/CD Pipelines
*   **Robust Scripting:** Avoided hardcoded values in `sed` commands. Patterns now target the structure of the YAML (`image: ...service:tag`) rather than specific IDs.
*   **Path-Based Triggers:** Configured `paths-ignore` for documentation and planning folders to avoid unnecessary builds and deployment cycles.
*   **Security:** Utilized GitHub Secrets for all sensitive data including AWS Credentials and Account IDs.

### 📊 Monitoring & Observability
*   **Full Stack Deployment:** Implemented the `kube-prometheus-stack` to provide real-time metrics (Prometheus) and visual dashboards (Grafana).
*   **Service Monitors:** Configured Kubernetes ServiceMonitors to automatically discover and scrape metrics from the boutique microservices.

### 🏗️ Infrastructure as Code
*   **State Management:** Maintained a clean separation between the infrastructure (Terraform) and the application delivery (Argo CD).

---

## 📈 Future Recommendations
1.  **Horizontal Pod Autoscaling (HPA):** Implement scaling based on CPU/Memory metrics.
2.  **External DNS/Ingress:** Replace port-forwarding with an AWS Load Balancer and a registered domain name.
3.  **Security Scanning:** Integrate image scanning (Trivy/Snyk) into the GitHub Actions pipeline.
