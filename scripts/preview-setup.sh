#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== Installing Node.js 22 ==="
for i in 1 2 3; do
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && break
  echo "Retry $i: nodesource setup failed"
  sleep 5
done
apt-get install -y nodejs nginx

echo "=== Cloning repo ==="
cd /opt
for i in 1 2 3 4 5; do
  git clone https://github.com/puppies-inc/storejs.git app && break
  echo "Retry $i: git clone failed"
  rm -rf app
  sleep 10
done

cd app
echo "=== Checking out PR #${PR_NUMBER} ==="
git fetch origin "pull/${PR_NUMBER}/head:pr-branch"
git checkout pr-branch

echo "=== Installing dependencies ==="
npm install --production

echo "=== Creating systemd service ==="
cat > /etc/systemd/system/storejs.service << 'EOF'
[Unit]
Description=StoreJS
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node src/server.js
Restart=always
Environment=PORT=3000
Environment=NODE_ENV=production
[Install]
WantedBy=multi-user.target
EOF

echo "=== Configuring nginx ==="
cat > /etc/nginx/sites-available/storejs << 'EOF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/storejs /etc/nginx/sites-enabled/

echo "=== Starting services ==="
systemctl daemon-reload
systemctl enable storejs nginx
systemctl start storejs
sleep 2
systemctl restart nginx

echo "SETUP_COMPLETE"
