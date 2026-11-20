# Production deployment

Primary host: `ssh neatorebackend` (`neatore@neatorebackend`).
Service directory: `~/Services/schoolzip` on the remote host.
Public API: https://schoolzip.tail2f41fe.ts.net
Komodo stack: `schoolzip`, server: `neatorebackend`.

## Layout and updates

Copy `server/` (excluding `.venv`, `target`, `data`, caches and secrets) into the remote service directory and copy `deploy/compose.yaml` to its root as `compose.yaml`. Keep remote `data/`, `backups/` and the Tailscale state volume intact. Then redeploy the `schoolzip` stack in Komodo, or run `docker compose up -d --build` from the remote service directory.

Komodo uses files on host, project name `schoolzip`, run directory `/mnt/ssd/home/neatore/Services/schoolzip`, and file `compose.yaml`. Build is enabled; automatic image pulling is disabled for the locally built API image. The real path is necessary because the periphery container mounts the SSD home directory.

The API runs as UID/GID 10001. Its persistent H2 database is `./data/teacher-names.mv.db`, mounted at `/data/teacher-names.mv.db`. Ensure UID 10001 can write to `data/`. The image contains no database or credentials. Java heap is capped at 512 MiB even if host cgroups do not enforce the Compose memory limit.

For a new installation only, authenticate the Tailscale sidecar using `docker compose exec tailscale tailscale up --hostname=schoolzip`, then enable public HTTPS with `docker compose exec tailscale tailscale funnel --bg http://api:8080`. Existing installations retain authentication and Funnel configuration in the `schoolzip_tailscale-state` volume. Never remove that volume during routine updates. No API port is published directly on the host.

Optional NEIS credentials belong in a remote `.env` file as `NEIS_API_KEY`, never in Git. Health check: `curl --fail https://schoolzip.tail2f41fe.ts.net/api/health`.

## Database backups and restore

For a consistent file backup, stop only `api`, copy `data/teacher-names.mv.db` to a dated file in `backups/`, then start `api` again. Do not copy an actively written H2 database. To restore, stop `api`, preserve the current database, copy the chosen backup into `data/teacher-names.mv.db`, restore UID/GID 10001 ownership, and start `api`. Verify the health endpoint and teacher-name candidates. Do not run `docker compose down -v`.

Initial migration copied the entire database from the Mac after a graceful backend shutdown. Source and destination SHA-256 matched; all 24 current Onam teacher-name candidates matched before and after API container recreation. Original database and dated backup remain on the Mac; the remote initial copy is `backups/teacher-names-initial.mv.db`.

## Mobile builds

Release builds default to the production HTTPS API. Debug builds default to the local development server. Override either with `--dart-define=API_BASE_URL=...`. Updating the app preserves settings and refreshes the widget API URL. The phone does not require Tailscale or a running Mac to access the public Funnel endpoint.
