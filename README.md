# HydraDB Spike

Feasibility test: runs the official open-source HydraDB engine
(`ghcr.io/hydra-db/hydradb:0.4.0`) on a free cloud container with local-disk
storage, then writes and reads a small graph and logs the result
(`[spike] SMOKE OK` / `SMOKE FAIL`).

- Listens on `$PORT` (Render) or 8443.
- `GET /healthz` answers without a token.
- Queries need a bearer token that is generated randomly at start-up and never printed.
- Storage is temporary: the graph resets when the container restarts.
- Sized for a 512 MB box (small caches, 1–2 threads).

HydraDB is licensed under the Elastic License 2.0 by its authors; this repo only
contains a Dockerfile and a start script that use the official image.
