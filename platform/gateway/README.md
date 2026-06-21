# gateway

Reverse proxy and platform entrypoint.

Recommended role:

- route external traffic to internal Laravel services
- centralize headers and request correlation
- expose `/api/*` upstreams
- serve `portal-web` as the default frontend

This component can remain infrastructure-oriented rather than business-oriented.
