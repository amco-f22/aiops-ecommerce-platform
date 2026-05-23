# 🔍 Iris — AIOps Assistant

> An AI-powered SRE agent built on **AWS Bedrock** that diagnoses production incidents in real time. Iris queries CloudWatch Logs, Prometheus metrics, and EKS cluster health — then responds with root cause analysis, evidence, and fix recommendations.

## Demo

https://github.com/user-attachments/assets/e6352c2c-cbf0-4349-878c-2c99b4e3079c

---

## How Iris Works

When an engineer asks "Why are we seeing 503 errors?", Iris doesn't guess — it investigates like a senior SRE:

```
Engineer asks a question
         │
         ▼
┌──────────────────────────────┐
│     Bedrock Agent (Iris)     │
│  Foundation Model: Qwen 3   │
│  Instruction: SRE persona   │
└──────────┬───────────────────┘
           │
   ┌───────┼───────────┐
   │       │           │
   ▼       ▼           ▼
┌──────┐ ┌──────┐ ┌──────────┐
│ Logs │ │Metrics│ │  Health  │
│Lambda│ │Lambda │ │  Lambda  │
└──┬───┘ └──┬───┘ └────┬─────┘
   │        │          │
   ▼        ▼          ▼
CloudWatch  Prometheus  EKS API
  Logs      (via ELB)   (cluster,
                        nodes, pods)
```

**The investigation flow:**

1. **Understand the symptom** — Parse the engineer's question to identify what's broken
2. **Form a hypothesis** — Based on experience (system prompt), decide which data sources to query
3. **Gather evidence** — Call one or more Lambda functions to pull logs, metrics, and health data
4. **Correlate** — Cross-reference findings across all three data sources
5. **Respond** — Deliver root cause, supporting evidence, immediate fix, and prevention steps

Iris never responds with generic advice. Every conclusion is backed by specific log entries, metric values, or pod status readings.

---

## Architecture

### Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Chat UI** | Streamlit (Python) | Terminal-style interface for interacting with Iris |
| **AI Engine** | AWS Bedrock Agent | Orchestrates tool calls and generates responses using a foundation model |
| **Foundation Model** | Qwen 3 (32B) | Language model that powers Iris's reasoning |
| **fetch_logs** | AWS Lambda (Python) | Queries CloudWatch Logs using `FilterLogEvents` |
| **fetch_metrics** | AWS Lambda (Python) | Queries Prometheus via HTTP for CPU, memory, latency, error rates |
| **fetch_health** | AWS Lambda (Python) | Calls EKS API for cluster, node group, and pod health status |
| **Action Schemas** | OpenAPI JSON | Defines the input/output contract for each Lambda so Bedrock knows when and how to call them |

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Streamlit UI (app.py)                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Engineer: "Why are we seeing 503 errors?"          │    │
│  └────────────────────────┬────────────────────────────┘    │
│                           │ invoke_agent()                   │
└───────────────────────────┼─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  AWS Bedrock Agent (Iris)                    │
│                                                             │
│  System Prompt: "You are Iris, a senior SRE with 12 years   │
│  of experience..."                                          │
│                                                             │
│  ┌─────────┐  ┌──────────┐  ┌───────────────┐             │
│  │fetch_logs│  │fetch_    │  │fetch_service_ │             │
│  │         │  │metrics   │  │health         │             │
│  └────┬────┘  └────┬─────┘  └──────┬────────┘             │
└───────┼────────────┼───────────────┼────────────────────────┘
        │            │               │
        ▼            ▼               ▼
   CloudWatch    Prometheus      EKS API
     Logs        (via ELB)    (DescribeCluster,
                              ListNodegroups,
                              DescribeNodegroup)
```

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| AWS Account | Bedrock model access enabled for your chosen foundation model |
| EKS Cluster | Running with Prometheus exposed via a LoadBalancer service |
| AWS CLI | Configured with `aws configure` (credentials that can access Bedrock, Lambda, EKS, CloudWatch) |
| Python | 3.10 or higher |

---

## Setup Guide

### Step 1 — Create IAM Roles

Run the provided script to create both required IAM roles:

```bash
chmod +x setup-iam.sh
./setup-iam.sh
```

This creates two roles:

| Role | Used By | Permissions |
|------|---------|-------------|
| `aiops-lambda-role` | All 3 Lambda functions | CloudWatch Logs read, EKS describe, Lambda basic execution |
| `aiops-bedrock-agent-role` | Bedrock Agent | Invoke the 3 Lambda functions, invoke Bedrock foundation models |

---

### Step 2 — Create Lambda Functions

Create the following 3 Lambda functions in the AWS Console (or via CLI). Use the code from the `lambda/` directory.

| Function Name | Code File | Execution Role |
|---------------|-----------|----------------|
| `aiops-fetch-logs` | `lambda/fetch_logs/lambda_function.py` | `aiops-lambda-role` |
| `aiops-fetch-metrics` | `lambda/fetch_metrics/lambda_function.py` | `aiops-lambda-role` |
| `aiops-fetch-health` | `lambda/fetch_health/lambda_function.py` | `aiops-lambda-role` |

**Runtime:** Python 3.12 | **Timeout:** 30 seconds

---

### Step 3 — Configure Prometheus URL

Both `fetch_metrics` and `fetch_health` query Prometheus directly via HTTP. Update the `PROMETHEUS_URL` placeholder in each Lambda before uploading.

In `lambda/fetch_metrics/lambda_function.py`:
```python
PROMETHEUS_URL = "http://<YOUR_PROMETHEUS_ELB_URL>:9090"
```

In `lambda/fetch_health/lambda_function.py`:
```python
PROMETHEUS_URL = "http://<YOUR_PROMETHEUS_ELB_URL>:9090"
```

**How to get the Prometheus ELB URL:**

```bash
# Expose Prometheus as a LoadBalancer
kubectl patch svc kube-prometheus-stack-prometheus -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Get the external URL
kubectl get svc kube-prometheus-stack-prometheus -n monitoring
# Copy the EXTERNAL-IP value — that is your ELB URL
```

> **Security Note:** The Prometheus ELB is publicly accessible on port 9090. For production, restrict access using Security Groups to only allow traffic from the Lambda function's VPC/NAT gateway IP. For this demo project, we leave it open for simplicity.

---

### Step 4 — Deploy the Bedrock Agent

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Verify the Lambda functions and IAM role exist
2. Set Lambda timeouts to 30s and add Bedrock invoke permissions
3. Create the Bedrock Agent (`aiops-assistant`) with the Iris system prompt
4. Attach all 3 action groups with their OpenAPI schemas
5. Prepare the agent for use

At the end, the script prints your **Agent ID** — save it for the next step.

---

### Step 5 — (Optional) Generate Sample Data

Populate CloudWatch Logs with realistic error scenarios to test Iris:

```bash
python3 scripts/generate_sample_data.py --region us-east-1
```

This writes 100 realistic log events to `/app/production` — including 503 errors, OOM kills, connection pool exhaustion, and timeout patterns that Iris can investigate.

---

### Step 6 — Run the Streamlit UI

```bash
cp .env.example .env
```

Edit `.env` and fill in your values:

```env
AWS_REGION=us-east-1
BEDROCK_AGENT_ID=<YOUR_AGENT_ID>
BEDROCK_AGENT_ALIAS_ID=TSTALIASID

# Optional — omit to use your AWS CLI profile / SSO / IAM role:
# AWS_ACCESS_KEY_ID=<YOUR_ACCESS_KEY>
# AWS_SECRET_ACCESS_KEY=<YOUR_SECRET_KEY>
# AWS_SESSION_TOKEN=<YOUR_SESSION_TOKEN>
```

Install dependencies and start the UI:

```bash
pip install -r requirements.txt
streamlit run app.py
```

Open **http://localhost:8501** in your browser.

---

## Project Structure

```
aiops-assistant/
├── app.py                  # Streamlit chat UI with dark terminal theme
├── deploy.sh               # Bedrock Agent deployment automation
├── setup-iam.sh            # IAM roles and policies setup
├── requirements.txt        # Python dependencies (streamlit, boto3)
├── .env.example            # Environment variable template
├── lambda/
│   ├── fetch_logs/         # CloudWatch Logs query (FilterLogEvents)
│   ├── fetch_metrics/      # Prometheus metrics query (PromQL via HTTP)
│   └── fetch_health/       # EKS cluster + node group health check
├── schemas/
│   ├── fetch_logs.json     # OpenAPI schema for fetch_logs action group
│   ├── fetch_metrics.json  # OpenAPI schema for fetch_metrics action group
│   └── fetch_health.json   # OpenAPI schema for fetch_health action group
└── scripts/
    └── generate_sample_data.py  # Seed CloudWatch with realistic test errors
```

---

## Sample Questions to Ask Iris

| Category | Question |
|----------|----------|
| **Error Investigation** | "Why are we seeing 503 errors in the last hour?" |
| **Resource Utilization** | "Is CPU usage high across the boutique services?" |
| **Database Health** | "Check database connections and latency" |
| **Pod Health** | "Are all pods healthy? Any restarts?" |
| **Log Analysis** | "What are the most frequent errors in the last 2 hours?" |
| **Memory Issues** | "Is there a memory leak in any service?" |
| **Incident Triage** | "The frontend is slow — help me diagnose" |

---

## Troubleshooting

### Bedrock model access not enabled
The deploy script will fail at agent creation if model access hasn't been requested. Go to **AWS Console → Bedrock → Model access** and enable access for the model used in `deploy.sh` before running the script.

### Prometheus URL unreachable from Lambda
`fetch_metrics` and `fetch_health` make outbound HTTP calls to the Prometheus ELB. If Lambda is deployed inside a VPC without a NAT gateway or internet gateway route, these calls will time out. Either:
- Keep Lambda outside a VPC (default), or
- Ensure the VPC has a route to the internet and the Prometheus ELB security group allows inbound on port 9090.

### Agent stuck in PREPARING state
After running `deploy.sh`, the agent status shows `PREPARING`. This is normal and takes 30–60 seconds. If it stays in this state, check the Bedrock console for validation errors — usually caused by a malformed OpenAPI schema or a Lambda ARN that doesn't exist.

### Streamlit shows "NOT CONFIGURED"
The app requires `BEDROCK_AGENT_ID` and `BEDROCK_AGENT_ALIAS_ID` to be set in `.env`. If you started Streamlit before populating `.env`, stop it and restart — `load_dotenv()` only reads the file at startup.

```bash
# Stop and restart
pkill -f "streamlit run app.py"
streamlit run app.py
```

### fetch_logs returns no results
The default log group is `/eks/boutique/pods`. This group is only created after Fluent Bit starts shipping logs. Make sure `aws-for-fluent-bit` is running:

```bash
kubectl get pods -n amazon-cloudwatch
```

If the log group doesn't exist yet, run the sample data generator first (Step 5) which creates `/app/production`.

### fetch_health uses wrong cluster name
The Lambda defaults to cluster name `eks-cluster`. If your cluster has a different name, update `DEFAULT_CLUSTER` in `lambda/fetch_health/lambda_function.py` before uploading the function code.

### Lambda execution role missing permissions
If `fetch_health` returns an access denied error on `eks:DescribeCluster`, the inline policy may not have propagated yet (IAM can take ~10–15 seconds). Wait and retry. If it persists, verify the inline policy is attached:

```bash
aws iam get-role-policy \
  --role-name aiops-lambda-role \
  --policy-name aiops-lambda-inline-policy
```

### AWS credentials not resolving in Streamlit
If `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are left blank in `.env`, boto3 falls back to the default credential chain (`~/.aws/credentials`, environment variables, IAM role). If none of those are configured, Bedrock calls will fail with an auth error. Either fill in the credentials in `.env` or ensure your terminal session has valid AWS credentials before starting Streamlit.
