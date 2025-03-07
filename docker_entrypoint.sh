#!/bin/sh
ADMIN_TOKEN=$(yq e '.admin-token' /data/start9/config.yaml)
VW_ADMIN_TOKEN=$(echo -n "$ADMIN_TOKEN" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
echo "ADMIN_TOKEN='${VW_ADMIN_TOKEN}'" >> /.env

TOR_ADDRESS=$(yq e .vaultwarden-tor-address /data/start9/config.yaml)
LAN_ADDRESS=$(yq e .vaultwarden-lan-address /data/start9/config.yaml)

# Erstellen eines selbstsignierten Zertifikats für LAN
mkdir -p /etc/ssl/vaultwarden
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/ssl/vaultwarden/lan.key -out /etc/ssl/vaultwarden/lan.crt \
  -subj "/CN=$LAN_ADDRESS" -addext "subjectAltName=DNS:$LAN_ADDRESS,IP:127.0.0.1"

cat << EOF >> /.env
PASSWORD_ITERATIONS=2000000
DOMAIN="https://$LAN_ADDRESS"
WEB_VAULT_ENABLED=true
EOF

cat << EOF > /data/start9/stats.yaml
version: 2
data:
  "Admin Token":
    type: string
    value: "$ADMIN_TOKEN"
    description: "Authentication token for logging into your admin dashboard."
    copyable: true
    qr: false
    masked: true
  "Local Admin URL":
    type: string
    value: "http://$LAN_ADDRESS/admin"
    description: "The URL for accessing your admin dashboard via your LAN."
    copyable: true
    qr: false
    masked: false
  "Tor Admin URL":
    type: string
    value: "https://$TOR_ADDRESS/admin"
    description: "The URL for accessing your admin dashboard via Tor."
    copyable: true
    qr: false
    masked: false
EOF

CONF_FILE="/etc/nginx/http.d/default.conf"
NGINX_CONF='
# SSL Server Block für Tor
server {
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
    application/atom+xml
    application/geo+json
    application/javascript
    application/x-javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rdf+xml
    application/rss+xml
    application/xhtml+xml
    application/xml
    font/eot
    font/otf
    font/ttf
    image/svg+xml
    text/css
    text/javascript
    text/plain
    text/xml;

    listen 3443 ssl;
    http2 on;
    ssl_certificate /mnt/cert/main.cert.pem;
    ssl_certificate_key /mnt/cert/main.key.pem;
    server_name localhost;
    client_max_body_size 128M;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        set_real_ip_from 0.0.0.0/0;
        proxy_redirect off;
        proxy_pass http://0.0.0.0:80;
    }

    location /notifications/hub {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://0.0.0.0:80;
    }
}

# SSL Server Block für LAN
server {
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
    application/atom+xml
    application/geo+json
    application/javascript
    application/x-javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rdf+xml
    application/rss+xml
    application/xhtml+xml
    application/xml
    font/eot
    font/otf
    font/ttf
    image/svg+xml
    text/css
    text/javascript
    text/plain
    text/xml;

    listen 8080 ssl;
    http2 on;
    ssl_certificate /etc/ssl/vaultwarden/lan.crt;
    ssl_certificate_key /etc/ssl/vaultwarden/lan.key;
    server_name localhost;
    client_max_body_size 128M;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        set_real_ip_from 0.0.0.0/0;
        proxy_redirect off;
        proxy_pass http://0.0.0.0:80;
    }

    location /notifications/hub {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://0.0.0.0:80;
    }
}
'
echo "$NGINX_CONF" > $CONF_FILE

nginx -g 'daemon off;' &
exec  tini -p SIGTERM -- /start.sh
