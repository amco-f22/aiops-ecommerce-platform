# System Integrations Mapping

This document lists and details the internal and external integrations of the DevOps + AIOps platform.

---

## 🔗 Internal Microservice Communications (REST API Map)

All client interactions route through the **API Gateway** (port `3001`), which acts as a reverse proxy, delegating requests to downstream microservices using stable Kubernetes DNS names inside EKS (or `localhost` for local Docker Compose development).

```
[Client / React Frontend :3000]
            │
            ▼
   [API Gateway :3001]
   ├── /api/auth   ──> [Auth Service :3002]
   ├── /api/products ──> [Product Service :3003]
   ├── /api/orders  ──> [Orders Service :3005]
   └── /api/users   ──> [User Service :3006]
```

### 📍 Service Endpoint Routing
| Route | Downstream Target | Underlying Port | Purpose |
|-------|-------------------|-----------------|---------|
| `/api/auth` | `auth` | `3002` | User sign-up, login, and token generation/verification. |
| `/api/products` | `product-service` | `3003` | Fetching products list, viewing individual product details, and image uploads. |
| `/api/orders` | `orders` | `3005` | Placing orders, retrieving order status, and purchasing. |
| `/api/users` | `user-service` | `3006` | Retrieving user profile information and updating billing address. |

---

## 🗄️ Database Integration Map

Downstream backend services possess exclusive connections to specialized databases hosted in a centralized PostgreSQL instance. This enforces loose coupling and bounded contexts.

| Microservice | Database Name | Connection Variable | Database Contents |
|--------------|---------------|---------------------|-------------------|
| `auth` | `auth_db` | `DATABASE_URL` | User account table (`users` credentials and roles). |
| `product-service` | `products_db` | `DATABASE_URL` | Catalog metadata (`products` data, category, descriptions). |
| `order-service` | `orders_db` | `DATABASE_URL` | Transactional data (`orders` and `order_items` details). |
| `orders` | `orders_db` | `DATABASE_URL` | Transactional data (`orders` and `order_items` details). |
| `user-service` | `users_db` | `DATABASE_URL` | Demographic / user profile information (`user_profiles` details). |

---

## 📊 Observability Integrations

Telemetry metrics and logs flow from our applications out to scraping servers and cloud aggregators.

```
[Application Containers]
       ├── (Scrape /metrics via prom-client) ──> [Prometheus :9090] ──> [Grafana :3007]
       └── (stdout Logs) ──> [AWS Fluent Bit] ──> [CloudWatch Logs /app/production]
```

### 1. Prometheus Telemetry scraping
* Downstream Node.js servers utilize `prom-client` to auto-expose runtime parameters (CPU, Memory, Request Duration) at the `/metrics` path.
* **ServiceMonitor (Kubernetes)**: Directs Prometheus server to scrape `/metrics` across all active pods at specified intervals.
* **Grafana Integration**: Grafana connects to Prometheus as a primary datasource to power telemetry dashboard visualization.

### 2. Log Aggregation
* **EKS Container Logs**: Fluent Bit daemonset runs on EKS nodes, scraping Docker logs from stdout/stderr.
* **Fluent Bit output**: Ships these raw logs directly to AWS CloudWatch Logs under the log group `/app/production`.

---

## 🤖 AWS Bedrock & AIOps (Kira) Integrations

Kira integrates AWS serverless execution with generative AI models to provide real-time SRE troubleshooting.

```
[Streamlit UI] ──> [AWS Bedrock Agent (Kira)]
                         │
        (Action Group / OpenAPI Schema calls)
                         │
                         ├──> [aiops-fetch-logs (Lambda)] ──> CloudWatch Logs
                         ├──> [aiops-fetch-metrics (Lambda)] ──> Prometheus Server (via ELB)
                         └──> [aiops-fetch-health (Lambda)] ──> EKS API / Cluster Health
```

### 1. Bedrock Agent Actions
Kira relies on **3 Lambda functions** exposed as Action Groups via OpenAPI schemas:
* **`fetch_logs` Action**: Triggers `aiops-fetch-logs` Lambda to parse CloudWatch log groups for specific time intervals, scanning for stacktraces, OOM errors, or database faults.
* **`fetch_metrics` Action**: Triggers `aiops-fetch-metrics` Lambda to perform PromQL queries against the cluster's Prometheus server.
* **`fetch_service_health` Action**: Triggers `aiops-fetch-health` Lambda, checking node states, CPU/Memory caps, and deployment health metrics.

### 2. Streamlit UI Client
* A lightweight Python dashboard invokes AWS Bedrock using `boto3.client('bedrock-agent-runtime')`.
* Passes user queries (e.g., *"Why is the product service slow?"*) to the Bedrock Agent, streaming back Kira's step-by-step reasoning and root cause analysis.
