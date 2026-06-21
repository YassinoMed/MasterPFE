# Service Incidents Runbook — SecureRAG Hub

> **Scope:** Application-level service incidents for SecureRAG Hub components.

---

## 1. Portal Web Down

### Symptoms
- HTTP 502/503 from portal.securerag.io
- Grafana dashboard shows 0% uptime for portal-web
- Users report "Page not loading" or "Internal Server Error"
- `kubectl get pods` shows portal-web pods not in `Running` state

### Diagnosis

```bash
# Check pod status
kubectl get pods -n securerag-hub -l app.kubernetes.io/name=portal-web

# Check deployment status
kubectl rollout status deploy/portal-web -n securerag-hub

# Get pod logs
kubectl logs -n securerag-hub -l app.kubernetes.io/name=portal-web --tail=100

# Check service endpoints
kubectl get endpoints portal-web -n securerag-hub

# Test internal connectivity
kubectl run curl-test --image=curlimages/curl:latest -it --rm -- \
  curl -v http://portal-web.securerag-hub.svc.cluster.local:8080/health

# Check ingress configuration
kubectl describe ingress portal-web -n securerag-hub

# Check last deployment revision
kubectl describe deploy/portal-web -n securerag-hub | grep -A5 "Replicas:"
```

### Resolution

1. **If pods not running:**
   - Follow Kubernetes runbook for CrashLoopBackOff or pending pods
2. **If misconfiguration:**
   - Check ConfigMap updates: `kubectl describe configmap portal-web-config`
   - Rollback to last known good revision: `kubectl rollout undo deploy/portal-web -n securerag-hub`
3. **If backend dependency missing:**
   - Check auth service, database, and API endpoints
   - Restart dependent services if needed
4. **If resource exhaustion:**
   - Increase replica count: `kubectl scale deploy/portal-web --replicas=3 -n securerag-hub`
   - Or modify HPA min replicas
5. **If ingress routing broken:**
   - Verify Service type and port match Ingress backend
   - Check Ingress controller logs (Nginx/Istio)

---

## 2. Auth Service Unavailable

### Symptoms
- Users cannot log in
- Portal shows "Authentication failed" or "Service unavailable"
- API calls return 401/503 for auth endpoints
- Dependent services report "upstream connect error" for auth service

### Diagnosis

```bash
# Check auth service status
kubectl get pods -n securerag-hub -l app.kubernetes.io/name=auth-service
kubectl describe pods -n securerag-hub -l app.kubernetes.io/name=auth-service

# Check auth logs
kubectl logs -n securerag-hub -l app.kubernetes.io/name=auth-service --tail=100

# Test auth endpoint directly
kubectl run curl-test --image=curlimages/curl:latest -it --rm -- \
  curl -v http://auth-service.securerag-hub.svc.cluster.local:8080/health

# Check if auth depends on database/Redis
kubectl get pods -n securerag-hub -l app.kubernetes.io/name=database

# Verify JWT secret rotation
kubectl get secret auth-jwt -n securerag-hub -o jsonpath='{.data}'
```

### Resolution

1. **If database dependency down:**
   - Restore database connection (see Database Connection Failure)
   - Verify DB connection string in Secret/ConfigMap
2. **If JWT secret mismatch:**
   - Rotate secrets consistently across all services
   - Verify `auth-jwt` secret is mounted correctly
3. **If OIDC provider unreachable:**
   - Check external identity provider status
   - Fall back to local authentication if available
4. **If internal error:**
   - Restart auth service: `kubectl rollout restart deploy/auth-service -n securerag-hub`
   - Rollback if recent deployment introduced bug
5. **If rate limiting active:**
   - Check rate limiter configuration
   - Temporarily increase rate limit if false positive

---

## 3. Chatbot High Latency

### Symptoms
- Chatbot responses exceed 5 seconds
- Grafana shows p95/p99 latency spikes for chatbot service
- Portal Web chat feature times out
- Prometheus records `http_request_duration_seconds` > 5s

### Diagnosis

```bash
# Check chatbot pod resource usage
kubectl top pods -n securerag-hub -l app.kubernetes.io/name=chatbot

# Check chatbot logs for slow operations
kubectl logs -n securerag-hub -l app.kubernetes.io/name=chatbot --tail=200 | grep -iE "slow|timeout|error|warn"

# Check LLM/Ollama service health
kubectl get pods -n securerag-hub -l app.kubernetes.io/name=ollama
kubectl logs -n securerag-hub -l app.kubernetes.io/name=ollama --tail=50

# Check database query performance
kubectl logs -n securerag-hub -l app.kubernetes.io/name=database --tail=50 | grep -iE "slow|long|duration"

# Check HPA metrics
kubectl get hpa chatbot -n securerag-hub
kubectl describe hpa chatbot -n securerag-hub

# Check Prometheus metrics directly
kubectl port-forward -n securerag-monitoring service/prometheus 9090:9090
# Then visit: http://localhost:9090/graph?g0.expr=rate(http_request_duration_seconds_sum[5m])
```

### Resolution

1. **If resource constrained:**
   - Increase chatbot replicas: `kubectl scale deploy/chatbot --replicas=3`
   - Increase resource limits if HPA is maxed out
2. **If LLM inference slow:**
   - Check Ollama pod health and resource usage
   - Consider reducing model size or enabling GPU acceleration
   - Implement request queuing or caching for common queries
3. **If database queries slow:**
   - Check for missing indexes
   - Verify connection pool settings
   - Add read replicas for query offloading
4. **If network latency:**
   - Check cross-service call latency in Istio/Traefik
   - Ensure services are in same namespace for local DNS
5. **If traffic spike:**
   - Confirm HPA is working and has adequate headroom
   - Adjust HPA target utilization downward (e.g., 50% → 70%)
   - Implement rate limiting at gateway if sustained overload

---

## 4. Database Connection Failures

### Symptoms
- Services report "connection refused" or "could not connect to server"
- Connection pool exhaustion errors in application logs
- Timeout errors on database queries
- kubectl describes pod with `Error from server: connection refused`

### Diagnosis

```bash
# Check database pod status
kubectl get pods -n securerag-hub -l app.kubernetes.io/name=database
kubectl describe pods -n securerag-hub -l app.kubernetes.io/name=database

# Check database logs
kubectl logs -n securerag-hub -l app.kubernetes.io/name=database --tail=200

# Test database connectivity from another pod
kubectl run db-test --image=postgres:16-alpine -it --rm -- \
  psql -h <database-svc> -U <user> -d <dbname> -c "SELECT 1"

# Check PVC status for database
kubectl get pvc -n securerag-hub | grep database

# Check database service endpoints
kubectl get endpoints <database-svc> -n securerag-hub

# Check connection pool settings
kubectl describe configmap database-config -n securerag-hub
```

### Resolution

1. **If database pod crash:**
   - Restart: `kubectl rollout restart statefulset/database -n securerag-hub`
   - Check for disk corruption if PVC data is critical
2. **If connection pool exhausted:**
   - Increase `max_connections` in database config
   - Reduce application connection pool size limits
   - Add PgBouncer or similar connection pooler
3. **If network policy blocking:**
   - Verify NetworkPolicy allows egress from application namespace to database
   - Check database service selector matches pod labels
4. **If authentication failure:**
   - Verify database secret: `kubectl get secret database-credentials -n securerag-hub`
   - Check `pg_hba.conf` for allowed connections
   - Rotate credentials if compromised
5. **If storage full:**
   - Free space: `kubectl exec <database-pod> -- df -h /var/lib/postgresql/data`
   - Increase PVC size or clear old WAL files
   - Run `VACUUM FULL` if excessive bloat

### Database Recovery Procedures

```bash
# Safe restart
kubectl rollout restart statefulset/database -n securerag-hub

# Scale to 0 and back (for full reset)
kubectl scale statefulset/database --replicas=0 -n securerag-hub
sleep 10
kubectl scale statefulset/database --replicas=1 -n securerag-hub

# Verify after restart
kubectl logs -n securerag-hub -l app.kubernetes.io/name=database --tail=20 | grep "database system is ready"
```
