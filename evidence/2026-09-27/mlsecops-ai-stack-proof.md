# MLSecOps — Preuves Stack IA (généré le 2026-09-27 22:44)

## 1. Ollama — Runtime LLM
```
ollama-d9c68bb77-tjnq9   1/1     Running   0          6m26s   10.244.0.10   securerag-dev-control-plane   <none>           <none>
ollama-models   Bound    pvc-0853c726-efd2-4082-bc00-4cde417b4213   5Gi        RWO            standard       <unset>                 10m
--- Modèles persistés (après restart du pod) ---
NAME                   ID              SIZE      MODIFIED      
qwen2.5-0.5b:latest    061603a438cb    491 MB    7 minutes ago    
```

## 2. Qdrant — Vector DB + RAG
```
Collection vuln-kb: {"status": "green", "optimizer_status": "ok", "indexed_vectors_count": 0, "points_count": 4, "segments_count": 2, "config": {"params": {"vectors": {"size": 4, "distance": "Cosine"}, "shard_number": 1, "replication_factor": 1, "write_consistency_factor": 1, "on_disk_payload": true}, "hnsw_config": {"m": 16, "ef_construct": 100, "full_scan_threshold": 10000, "max_indexing_threads": 0, "on_disk": false}, "optimizer_config": {"deleted_threshold": 0.2, "vacuum_min_vector_number": 1000, "default_segment_number": 0, "max_segment_size": null, "memmap_threshold": null, "indexing_threshold": 10000, "flush_interval_sec": 5, "max_optimization_threads": null, "prevent_unoptimized": null}, "wal_config": {"wal_capacity_mb": 32, "wal_segments_ahead": 0, "wal_retain_closed": 1}, "quantization_config": null}, "payload_schema": {}, "update_queue": {"length": 0}}
```

## 3. Signature Cosign des images IA
```

[{"critical":{"identity":{"docker-reference":"localhost:5001/ollama@sha256:4be1eaabf0dd0152bfbb780347e2888b5fe86ec25d0faa3eb4b1a956173736fb"},"image":{"docker-manifest-digest":"sha256:4be1eaabf0dd0152bfbb780347e2888b5fe86ec25d0faa3eb4b1a956173736fb"},"type":"https://sigstore.dev/cosign/sign/v1"},"optional":{}}]
```

## 4. Guardrails — 28/28 tests PASS
```
28 passed in 0.20s
```

## 5. Suite SECAI complète (non-régression)
```
52 passed in 0.34s
```
