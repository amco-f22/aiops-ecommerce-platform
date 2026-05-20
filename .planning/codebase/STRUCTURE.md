# Codebase Structure

This document diagrams the folder structure, directory layout, and naming patterns used across the DevOps + AIOps repository.

---

## 📂 Repository Directory Tree

```
DevOps-Practice-Guide/
├── .planning/                  # [NEW] Codebase scan and architectural maps
│   └── codebase/
│       ├── STACK.md            # Languages, databases, runtimes list
│       ├── INTEGRATIONS.md     # Service endpoints & Bedrock lambda mappings
│       ├── ARCHITECTURE.md     # Distributed layout & GitOps sequence charts
│       └── STRUCTURE.md        # [This file] Repository folder topology
├── docs/                       # Comprehensive series reference manuals
│   ├── part1-system-design.md  # Core DevOps/SRE architectural pillars
│   ├── part2-workflow.md       # Dev-to-Prod pipelines & AIOps logic
│   └── claude-setup.md         # Environment configurations & MCP servers
├── gitops/                     # Continuous Delivery (ArgoCD) manifests
│   ├── argo-cd.yml             # ArgoCD Application configuration
│   ├── kustomization.yml       # Overlay resource aggregator
│   ├── namespace.yml           # Cluster namespace definitions (`boutique`)
│   ├── secrets.yml             # Credentials (e.g. database password secrets)
│   └── k8s/                    # Core declarative Kubernetes manifests
│       ├── backend/            # Deployments, Services, ServiceMonitor
│       ├── database/           # StatefulSet, Service, SQL scripts, DB restore
│       └── frontend/           # Nginx frontend deployments
└── projects/                   # Multi-service source code
    ├── Issues.md               # Collection of intentional bugs & debug actions
    ├── README.md               # Main instructions on compiling/deploying
    ├── boutique-microservices/ # The application source files
    │   ├── docker-compose.yml  # Local multi-container wireframe
    │   ├── backend/            # Express.js + TS microservices
    │   │   ├── shared/         # Common TypeScript models & types
    │   │   └── services/       # 6 isolated Node/TS packages
    │   └── frontend/           # Single-Page React Web Application
    ├── Infrastructure/         # Terraform configurations
    │   ├── main.tf             # Master Terraform layout
    │   └── modules/            # Local Terraform modules (VPC, EKS, ECR, Argo)
    └── aiops-assistant/        # Bedrock Agent Kira source code
        ├── app.py              # Streamlit chatbot interface
        ├── deploy.sh           # Bedrock Agent CLI setup script
        ├── setup-iam.sh        # Role and policy setup script
        └── lambda/             # Python-based Bedrock tool functions
```

---

## 🔍 Key Directory Descriptions

### 1. `projects/boutique-microservices`
* The application layer containing independent codebases.
* **Frontend**: React-based codebase with its own `package.json`, custom nginx configurations (`nginx.conf`), and Emotion/MUI styling.
* **Backend Services**: Contains custom TypeScript packages (`auth`, `gateway`, `product-service`, `orders`, `user-service`) and a plain Node.js service (`order-service`).
  * Backend services use `prom-client` to expose metric endpoints.
  * Shared models and type bindings are extracted into a `shared/` directory.

### 2. `projects/Infrastructure`
* Declarative Infrastructure-as-Code.
* Segmented into reusable Terraform modules:
  * `vpc`: Provisions virtual private network, subnets across three availability zones.
  * `eks`: Deploys managed Elastic Kubernetes Service, IAM policies, and Node Groups.
  * `ecr`: Provisions ECR registries to store Docker images.
  * `argocd`: Deploys ArgoCD into EKS via Helm provider.

### 3. `gitops`
* Production deployment manifests.
* Uses **Kustomize** to merge individual service configurations.
* Contains `k8s/database/boutique_full.sql`, which houses the raw DDL/DML to populate database tables on deployment.

### 4. `projects/aiops-assistant`
* SRE troubleshooting engine.
* Contains Streamlit frontend chat code (`app.py`), OpenAPI schemas (`schemas/`), and Python action code (`lambda/`) that the generative AI runs to monitor clusters.
