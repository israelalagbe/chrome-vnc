# Lightweight base image
FROM debian:bookworm-slim

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0 \
    VNC_PASSWORD="vncpassword" \
    USER_ID=1000 \
    GROUP_ID=1000 \
    DISPLAY_WIDTH=1920 \
    DISPLAY_HEIGHT=1080 \
    WEB_LISTENING_PORT=5800 \
    VNC_LISTENING_PORT=5900 \
    KEEP_APP_RUNNING=1 \
    APP_NAME="Chrome" \
    DARK_MODE=0

# Install dependencies including noVNC
RUN apt-get update && apt-get install -y \
    # Core utilities
    sudo \
    curl \
    wget \
    ca-certificates \
    supervisor \
    nginx \
    # Display server and VNC
    xvfb \
    x11vnc \
    openbox \
    xterm \
    # noVNC for web interface
    novnc \
    websockify \
    python3 \
    # Chrome dependencies
    chromium \
    chromium-driver \
    # Fonts and rendering
    fonts-liberation \
    fonts-noto \
    fonts-noto-color-emoji \
    # Required libraries
    libnss3 \
    libxss1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libgbm1 \
    libxshmfence1 \
    # Utilities
    procps \
    dbus-x11 \
    xauth \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -g ${GROUP_ID} appuser && \
    useradd -u ${USER_ID} -g ${GROUP_ID} -m -s /bin/bash appuser && \
    echo "appuser:${VNC_PASSWORD}" | chpasswd && \
    mkdir -p /etc/sudoers.d && \
    echo "appuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/appuser && \
    chmod 0440 /etc/sudoers.d/appuser

# Create necessary directories
RUN mkdir -p \
    /config \
    /config/chrome \
    /config/logs \
    /config/certs \
    /defaults \
    /var/log/supervisor \
    /usr/share/novnc \
    && chown -R appuser:appuser /config

# Copy noVNC files
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Setup nginx for web access
RUN rm -f /etc/nginx/sites-enabled/default
COPY <<'EOF' /etc/nginx/sites-available/novnc
server {
    listen ${WEB_LISTENING_PORT} default_server;
    listen [::]:${WEB_LISTENING_PORT} default_server;
    
    root /usr/share/novnc;
    index index.html;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /websockify {
        proxy_pass http://127.0.0.1:6080/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
}
EOF

RUN ln -s /etc/nginx/sites-available/novnc /etc/nginx/sites-enabled/novnc

# Create supervisor config
COPY <<'EOF' /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:xvfb]
command=/usr/bin/Xvfb :0 -screen 0 %(ENV_DISPLAY_WIDTH)sx%(ENV_DISPLAY_HEIGHT)sx24 -ac +extension GLX +render -noreset
user=appuser
autostart=true
autorestart=true
priority=10
stdout_logfile=/config/logs/xvfb.log
stderr_logfile=/config/logs/xvfb-error.log

[program:openbox]
command=/usr/bin/openbox --config-file /etc/xdg/openbox/rc.xml
user=appuser
environment=DISPLAY=":0"
autostart=true
autorestart=true
priority=15
stdout_logfile=/config/logs/openbox.log
stderr_logfile=/config/logs/openbox-error.log

[program:x11vnc]
command=/usr/bin/x11vnc -display :0 -forever -shared -rfbport %(ENV_VNC_LISTENING_PORT)s -passwd %(ENV_VNC_PASSWORD)s -ncache 10
user=appuser
autostart=true
autorestart=true
priority=20
stdout_logfile=/config/logs/x11vnc.log
stderr_logfile=/config/logs/x11vnc-error.log

[program:websockify]
command=/usr/bin/websockify --web /usr/share/novnc 6080 127.0.0.1:%(ENV_VNC_LISTENING_PORT)s
user=appuser
autostart=true
autorestart=true
priority=25
stdout_logfile=/config/logs/websockify.log
stderr_logfile=/config/logs/websockify-error.log

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
priority=30
stdout_logfile=/config/logs/nginx.log
stderr_logfile=/config/logs/nginx-error.log

[program:chrome]
command=/usr/bin/chromium
    --no-sandbox
    --disable-dev-shm-usage
    --disable-gpu
    --disable-software-rasterizer
    --disable-background-networking
    --disable-sync
    --disable-translate
    --disable-extensions
    --disable-default-apps
    --no-first-run
    --remote-debugging-address=0.0.0.0
    --remote-debugging-port=9222
    --user-data-dir=/config/chrome
    --start-maximized
    --window-size=%(ENV_DISPLAY_WIDTH)s,%(ENV_DISPLAY_HEIGHT)s
user=appuser
environment=DISPLAY=":0",HOME="/home/appuser"
autostart=true
autorestart=%(ENV_KEEP_APP_RUNNING)s
priority=40
stdout_logfile=/config/logs/chrome.log
stderr_logfile=/config/logs/chrome-error.log
stopwaitsecs=10
EOF

# Create startup script
COPY <<'EOF' /usr/local/bin/start.sh
#!/bin/bash
set -e

# Set user/group IDs if changed
if [ "${USER_ID}" != "1000" ] || [ "${GROUP_ID}" != "1000" ]; then
    echo "Updating user/group IDs to ${USER_ID}:${GROUP_ID}..."
    groupmod -g ${GROUP_ID} appuser
    usermod -u ${USER_ID} -g ${GROUP_ID} appuser
    chown -R appuser:appuser /config /home/appuser
fi

# Update nginx config with actual port
sed -i "s/listen .*;/listen ${WEB_LISTENING_PORT};/" /etc/nginx/sites-available/novnc
sed -i "s/listen \[::\]:.*;/listen [::]:${WEB_LISTENING_PORT};/" /etc/nginx/sites-available/novnc

# Start supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
EOF

RUN chmod +x /usr/local/bin/start.sh

# Expose ports
EXPOSE ${WEB_LISTENING_PORT} ${VNC_LISTENING_PORT} 9222

# Set working directory
WORKDIR /config

# Volume for persistent data
VOLUME ["/config"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:${WEB_LISTENING_PORT}/ || exit 1

# Start everything
CMD ["/usr/local/bin/start.sh"]