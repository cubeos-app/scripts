# CubeOS System Scripts

Utility scripts for CubeOS system management.

| Script | Purpose |
|--------|---------|
| `configure-npm.sh` | Configure Nginx Proxy Manager |
| `deploy-coreapps.sh` | Deploy core Docker services |
| `setup-ap.sh` | Configure WiFi Access Point |
| `status.sh` | Check service status |
| `stop-coreapps.sh` | Stop core services |

## CI/CD
- **lint**: shellcheck on all `.sh` files
- **deploy**: sync to Pi (main branch only)
