# Tetragon Network TracingPolicies

Tetragon can also trace network activity at the eBPF level.
For comprehensive network policies, use CiliumNetworkPolicies instead.

To enable network tracing in Tetragon:
```yaml
kprobes:
  - call: "tcp_connect"
    syscall: false
    args:
      - index: 0
        type: "sock"
  - call: "tcp_close"
    syscall: false
    args:
      - index: 0
        type: "sock"
```
