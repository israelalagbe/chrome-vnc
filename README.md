# Docker Container for Chrome

A Docker container for Chromium browser with VNC and noVNC web access

## Features

- **Web-based GUI**: Access Chrome through your browser at http://localhost:5800
- **VNC Access**: Connect via VNC client at localhost:5900
- **noVNC**: Built-in web-based VNC client (no installation needed)
- **Chrome DevTools**: Remote debugging at http://localhost:9222
- **Persistent Storage**: Chrome profile and data persist across restarts

## Quick Start

```bash
# Build and start the container
docker compose up --build chrome

# Or just start if already built
docker compose up chrome
```

## Access Points

| Service | URL/Address | Description |
|---------|-------------|-------------|
| Web Interface (noVNC) | http://localhost:5800 | Browser-based GUI access |
| VNC Client | localhost:5900 | Direct VNC connection |
| Chrome DevTools | http://localhost:9222 | Remote debugging protocol |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `USER_ID` | 1000 | User ID for file permissions |
| `GROUP_ID` | 1000 | Group ID for file permissions |
| `VNC_PASSWORD` | vncpassword | VNC connection password |
| `DISPLAY_WIDTH` | 1920 | Display width in pixels |
| `DISPLAY_HEIGHT` | 1080 | Display height in pixels |
| `WEB_LISTENING_PORT` | 5800 | noVNC web interface port |
| `VNC_LISTENING_PORT` | 5900 | VNC server port |
| `KEEP_APP_RUNNING` | 1 | Auto-restart Chrome on crash |
| `DARK_MODE` | 0 | Enable dark mode (0=off, 1=on) |

## Volumes

| Path | Description |
|------|-------------|
| `/config` | Chrome profile, logs, and configuration |
| `/config/chrome` | Chrome user data directory |
| `/config/logs` | Service logs (xvfb, vnc, chrome, etc.) |
| `/config/certs` | SSL certificates (for secure connections) |

## Logs

All logs are stored in `/config/logs/`:
- `xvfb.log` - Display server
- `openbox.log` - Window manager
- `x11vnc.log` - VNC server
- `websockify.log` - WebSocket proxy
- `nginx.log` - Web server
- `chrome.log` - Chrome browser
- `supervisord.log` - Process manager

## Examples

### Access via Web Browser

```bash
# Open in your browser
open http://localhost:5800

# Or with curl to check status
curl http://localhost:5800
```

### Access via VNC Client

```bash
# Using TigerVNC
vncviewer localhost:5900

# Using macOS Screen Sharing
open vnc://localhost:5900
```

### Check Chrome DevTools

```bash
# Get version info
curl http://localhost:9222/json/version

# List all pages/tabs
curl http://localhost:9222/json/list
```

### Custom Configuration

```yaml
# docker-compose.yml
services:
  chrome:
    environment:
      - DISPLAY_WIDTH=2560
      - DISPLAY_HEIGHT=1440
      - VNC_PASSWORD=mysecurepassword
      - KEEP_APP_RUNNING=1
      - DARK_MODE=1
```

### Change User/Group IDs

```yaml
services:
  chrome:
    environment:
      - USER_ID=1001
      - GROUP_ID=1001
```

## Troubleshooting

### Container won't start

Check logs:
```bash
docker compose logs chrome
```

### Can't connect to web interface

1. Verify nginx is running:
```bash
docker compose exec chrome supervisorctl status nginx
```

2. Check nginx logs:
```bash
docker compose exec chrome cat /config/logs/nginx.log
```

### Chrome crashes repeatedly

1. Check Chrome logs:
```bash
docker compose exec chrome cat /config/logs/chrome.log
```

2. Increase shared memory:
```yaml
services:
  chrome:
    shm_size: 4g  # Increase from 2g
```

### VNC connection refused

1. Check x11vnc status:
```bash
docker compose exec chrome supervisorctl status x11vnc
```

2. Verify VNC port:
```bash
docker compose exec chrome netstat -tulpn | grep 5900
```

### Remote debugging not working

1. Check Chrome is running with debugging:
```bash
curl http://localhost:9222/json/version
```

2. View Chrome command line:
```bash
docker compose exec chrome ps aux | grep chromium
```

## Security Considerations

1. **VNC Password**: Change default password in production
2. **Firewall**: Don't expose ports 5800/5900 to the internet
3. **User Permissions**: Use non-root user (already configured)
4. **Volume Permissions**: Match USER_ID/GROUP_ID with host user

## Integration with Puppeteer

The Puppeteer service connects to this Chrome container:

```typescript
// In puppeteer-agent.service.ts
private readonly BROWSER_URL = 'http://localhost:9222';

// Connect to Chrome
this.browser = await puppeteer.connect({
  browserURL: this.BROWSER_URL,
  defaultViewport: null,
});
```

## Performance Tips

1. **Shared Memory**: Allocate enough shared memory (2GB minimum)
2. **CPU Limits**: Don't restrict CPU too much (Chrome needs resources)
3. **Network**: Use host network for better performance if needed
4. **Display Resolution**: Lower resolution = better performance