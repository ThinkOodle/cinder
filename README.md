# Cinder

Short-lived log uploads for Omarchy. Boring, constrained, disposable.

Logs come in. Cinders are what's left after they burn out — and after 24 hours, even those are gone.

## API

```
POST /
  multipart: file=@log.txt, expires=24 (optional, hours)
  → 201, body is "<absolute URL>\n"

GET /:slug
  → 200, text/plain; charset=utf-8, X-Content-Type-Options: nosniff
  → 404 for unknown, expired, deleted, or blocked

GET /up
  → 200 health check
```

Errors are plain text. No HTML, ever.

## Limits

| Setting                       | Default | Env var                        |
| ----------------------------- | ------- | ------------------------------ |
| Max upload size               | 10 MB   | `CINDER_MAX_UPLOAD_BYTES`      |
| Default TTL (hours)           | 24      | `CINDER_DEFAULT_TTL_HOURS`     |
| Min TTL (hours)               | 1       | `CINDER_MIN_TTL_HOURS`         |
| Max TTL (hours, hard cap)     | 24      | `CINDER_MAX_TTL_HOURS`         |
| Cleanup grace (minutes)       | 60      | `CINDER_CLEANUP_GRACE_MINUTES` |
| Rate limit per minute per IP  | 5       | (in controller)                |
| Rate limit per hour per IP    | 25      | (in controller)                |

Binary content, archives, and images are rejected with `415`. Oversize uploads get `413`. Invalid `expires` falls back to the default TTL.

## Operator

```bash
bin/rails 'cinder:delete[slug]'   # soft-delete + purge file
bin/rails 'cinder:block[slug]'    # mark blocked (returns 404 publicly)
bin/rails cinder:cleanup          # run cleanup now
bin/rails cinder:stats            # counts by status
```

IP/User-Agent blocking lives at the Cloudflare edge, not in Rails.

## Cleanup

`CleanupExpiredUploadsJob` runs every 15 minutes via Solid Queue (see `config/recurring.yml`). It soft-deletes uploads past `expires_at + cleanup_grace`. Read paths also enforce expiry, so even if cleanup is delayed, expired logs stop being served immediately.

In production, configure your object storage bucket with a 1–2 day lifecycle rule as a safety net.

## Storage

Active Storage. Disk by default. Switch to S3/R2 by editing `config/storage.yml` and setting `config.active_storage.service` in `config/environments/production.rb`.

## Deployment

This repo only publishes the application image. To deploy it, build your own thin overlay image (`FROM ghcr.io/thinkoodle/cinder:<tag>`) that adds whatever environment-scoped credentials your instance needs, and point Kamal at that overlay.

The image expects:

- `RAILS_MASTER_KEY` for environment-scoped credentials.
- `SOLID_QUEUE_IN_PUMA=1` so the recurring cleanup job runs in-process — no separate worker.
- `CINDER_HOSTS` to lock the `Host` header (comma-separated).
- Object storage configured in `config/storage.yml` (R2 example included) and pointed at by `config.active_storage.service` in the right environment file.
- Cloudflare in front for WAF, IP/ASN blocks, and edge rate limits.
- Object-storage bucket lifecycle policy of 1–2 days as a safety net behind `CleanupExpiredUploadsJob`.

Releases are tagged `vX.Y.Z`; GitHub Actions builds and pushes `ghcr.io/thinkoodle/cinder:vX.Y.Z` (plus `:main` on every push to main).

## Metadata retention

Log content lives only until `expires_at + cleanup_grace`. Upload metadata (slug, sha256, ip, ua, status) persists after the file is purged so operators can investigate abuse and prevent re-uploads. There is no automatic metadata purge — prune it via Rails console when the audit window expires.

## Tests

```bash
bin/rails test
```
