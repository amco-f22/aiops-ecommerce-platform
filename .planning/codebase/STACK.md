# Tech Stack Mapping

This document provides a comprehensive mapping of the technology stack utilized in the DevOps + AIOps platform.

---

## 💻 Language & Application Runtimes

The platform is designed around a modern monorepo structure using **npm workspaces**, allowing unified dependency management and local development workflows.

### 🌐 Frontend Tier
* **Library**: React 19.2.4
* **UI Components**: Material UI (MUI) v7.3.7
* **Styling**: Emotion React & Emotion Styled
* **Build System**: React Scripts 5.0.1 (Webpack-based)
* **Runtime Node Version**: `>=20.0.0`
* **Web Server (Production)**: Nginx Alpine

### ⚙️ Backend Services Tier
* **Primary Language**: Node.js & TypeScript v5.2.2
* **Web Framework**: Express.js v4.18.x / v4.19.x
* **Security & Routing**: Helmet.js v7.1.0, CORS v2.8.5, Joi v17.11.0 (Validation)
* **HTTP Client**: Axios v1.6.x
* **Image Processing**: Sharp.js v0.32.6, Multer v1.4.5 (in `product-service`)

---

## 🗄️ Database & Storage Layer

* **Primary Database**: PostgreSQL v15 (Alpine-based container locally)
* **Driver**: node-postgres (`pg` v8.11.x)
* **Provisioning**: Multi-database initialization via local SQL dumps.
* **Database Segmentation**:
  * `auth_db`: User credentials & session states.
  * `products_db`: Product categories, metadata, & inventory.
  * `orders_db`: Transactional logs & purchase histories.
  * `users_db`: Customer profile information & delivery addresses.
* **Persistent Storage**: AWS Elastic Block Store (EBS) via EBS CSI Driver in Kubernetes (EKS).

---

## 🐳 Containerization & Local Orchestration

* **Container Engine**: Docker
* **Local Multi-Container Orchestration**: Docker Compose
  * Wires all 7 applications, Postgres, Prometheus, and Grafana on a shared bridge network (`boutique-network`).
  * Integrates database healthchecks (`pg_isready`) for deterministic startup ordering.

---

## ☁️ Cloud & Infrastructure Automation

* **Infrastructure-as-Code**: Terraform v1.x
* **Cloud Provider**: Amazon Web Services (AWS)
* **Key Provisioned Resources**:
  * **VPC**: 3 Availability Zones (`us-east-1a`, `us-east-1b`, `us-east-1c`) with private/public subnets.
  * **EKS (Elastic Kubernetes Service)**: Node groups using `t3.large` or `m7i-flex.large` instances to guarantee high pod capacity.
  * **ECR (Elastic Container Registry)**: Image repositories for each of the 7 microservices.
  * **Helm Integrations**: Installed directly via Terraform to bootstrap ArgoCD and kube-prometheus-stack.

---

## 📊 Observability & Telemetry

* **Metrics Collector**: Prometheus (exposed via LoadBalancer in AWS)
* **Node Telemetry**: `prom-client` v15.1.0 (instrumented inside Express.js middleware)
* **Metrics Scrape Endpoint**: `/metrics`
* **Visualization**: Grafana (custom-designed dashboards reading from Prometheus datasource)
* **Log Shipper**: AWS Fluent Bit forwarding container stdout to Amazon CloudWatch Logs.

---

## 🤖 AIOps & Intelligent SRE Agent

* **Agent Framework**: AWS Bedrock Agent (Kira)
* **Base Large Language Model**: Anthropic Claude 3 / 3.5 Sonnet on AWS Bedrock
* **Orchestration / Logic Layer**: Python 3.12 Lambdas
  * `aiops-fetch-logs`: Pulls telemetry from Amazon CloudWatch Logs.
  * `aiops-fetch-metrics`: Connects to Prometheus server.
  * `aiops-fetch-health`: Assesses EKS cluster/node telemetry.
* **UI layer**: Streamlit app (Python 3.10+) utilizing Boto3 to invoke Bedrock.
