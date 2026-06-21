# AI Security Layer - DevSecOps Platform Extension

This directory contains the code, manifests, and configurations for the **AI Security Layer**, which transforms the existing SecureRAG Hub into an AI-driven DevSecOps platform.

It deploys the HuggingFace model `omasteam/cyberguard-ai-security-analyzer` in a robust, high-availability architecture to inspect logs from various security and infrastructure components in real time.

---

## 1. Architecture Overview

```mermaid
graph TD
    %% Define components
    subgraph DevSecOps Infrastructure
        Loki[Loki Logs]
        Prom[Prometheus Alerts]
        K8sEv[K8s Event API]
    end

    subgraph AI Security Namespace (ai-security)
        Collector[Log Collector Daemon]
        Backend[FastAPI Backend API]
        Inference[AI Inference Service]
        DB[(PostgreSQL Database)]
        Web[React UI Dashboard]
    end

    %% Define data flows
    Loki -->|Poll logs| Collector
    Prom -->|Poll alerts| Collector
    K8sEv -->|Poll events| Collector
    
    Collector -->|POST /analyze| Backend
    Backend -->|Proxy /analyze| Inference
    Inference -->|HuggingFace Model / Heuristics| Backend
    
    Backend -->|Persist results & incidents| DB
    Backend -->|WebSockets broadcast| Web
    Web -->|REST APIs| Backend
```

The system is composed of five core modules:
1. **AI Inference Service** (`app.py`): Runs the HuggingFace model `omasteam/cyberguard-ai-security-analyzer`. It features a PyTorch backend with a high-fidelity **Heuristic Fallback Engine** to guarantee reliable execution on CPU-only or low-memory nodes.
2. **Log Collector** (`log_collector.py`): Periodically fetches logs and alerts from Loki, Prometheus, and the Kubernetes API, forwarding them to the backend API.
3. **FastAPI Backend** (`backend/main.py`): Serves as the central API orchestration layer. It handles DB persistence, filters, analytics, and broadcasts live alert payloads over WebSockets.
4. **PostgreSQL Database**: Persists threat classification logs (`analysis_results`) and long-term history records (`security_incidents`).
5. **React Dashboard** (`frontend/`): A premium dark-mode SPA built using React, TypeScript, and Material UI for live monitoring of threat trends, detailed alert diagnostics, and AI-powered remediation advice.

---

## 2. API Endpoints (OpenAPI Description)

The backend exposes the following endpoints:

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/health` | Service status check |
| `POST` | `/analyze` | Receives raw logs, proxies analysis, saves results, and raises incidents for MALICIOUS events. |
| `GET` | `/logs` | Returns all log analyses with filter parameters (`source`, `classification`, `severity`). |
| `GET` | `/alerts` | Returns only logs classified as `SUSPICIOUS` or `MALICIOUS`. |
| `GET` | `/incidents` | Returns the security incidents log history. |
| `PUT` | `/incidents/{id}/status` | Updates status of an incident (`OPEN`, `INVESTIGATING`, `RESOLVED`). |
| `GET` | `/sources` | Lists active log sources. |
| `GET` | `/statistics` | Returns grouped counts for charts. |
| `GET` | `/dashboard` | Returns KPIs, global risk indexes, and top-source rankings. |
| `WS` | `/ws` | WebSocket endpoint streaming live events to the frontend. |

---

## 3. Running & Deployment Instructions

### Local Development Setup
1. **Launch Inference Service**:
   ```bash
   cd ai-security
   pip install -r requirements.txt
   MOCK_INFERENCE=true python app.py
   ```
2. **Launch Backend Service**:
   ```bash
   cd ai-security/backend
   pip install -r requirements.txt
   DATABASE_URL=postgresql://postgres:postgres@localhost:5432/ai_security INFERENCE_SERVICE_URL=http://localhost:8000 uvicorn main:app --port 8080
   ```
3. **Launch Log Collector**:
   ```bash
   cd ai-security
   BACKEND_URL=http://localhost:8080 MOCK_LOGS=true python log_collector.py
   ```
4. **Launch Frontend**:
   ```bash
   cd ai-security/frontend
   npm install
   npm run dev
   ```

### Kubernetes Native Deployment
All components are deployed under the `ai-security` namespace using declarative manifests located in `ai-security/k8s/`:

```bash
# 1. Create the namespace (with Istio injection and PodSecurity enabled)
kubectl apply -f ai-security/k8s/namespace.yaml

# 2. Deploy PostgreSQL and K8s resources
kubectl apply -f ai-security/k8s/
```

This sets up:
- Isolating firewall rules (**NetworkPolicies**) preventing external access to internal database/inference pods.
- High availability via **HPAs** and **PodDisruptionBudgets**.
- Automatic observability configuration with **ServiceMonitors** for Prometheus scraping and ConfigMaps with a dedicated **Grafana Dashboard**.
