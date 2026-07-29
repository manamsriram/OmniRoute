#!/usr/bin/env bash
# One-time setup for a fresh Oracle Cloud (Always Free) VM to run OmniRoute.
# Run this ON the VM (over SSH), not locally:
#   scp scripts/deploy/oci-vm-setup.sh ubuntu@<vm-ip>:~/
#   ssh ubuntu@<vm-ip> 'bash ~/oci-vm-setup.sh'
set -euo pipefail

IMAGE="ghcr.io/${GHCR_OWNER:?set GHCR_OWNER=<your-github-username>}/omniroute:latest-release"

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi

sudo mkdir -p /opt/omniroute/data
sudo chown -R "$USER:$USER" /opt/omniroute

if [ ! -f /opt/omniroute/.env ]; then
  {
    echo "JWT_SECRET=$(openssl rand -base64 48)"
    echo "API_KEY_SECRET=$(openssl rand -hex 32)"
    echo "INITIAL_PASSWORD=changeme"
    echo "PORT=20128"
  } > /opt/omniroute/.env
  echo "Wrote /opt/omniroute/.env — change INITIAL_PASSWORD after first login."
fi

cat > ~/omniroute-deploy.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
docker pull "$IMAGE"
docker stop omniroute >/dev/null 2>&1 || true
docker rm omniroute >/dev/null 2>&1 || true
docker run -d --name omniroute --restart unless-stopped \\
  -p 20128:20128 \\
  --env-file /opt/omniroute/.env \\
  -v /opt/omniroute/data:/app/data \\
  "$IMAGE"
EOF
chmod +x ~/omniroute-deploy.sh

bash ~/omniroute-deploy.sh

echo ""
echo "Done. Container running: docker ps"
echo "Logs: docker logs -f omniroute"
echo ""
echo "Open port 20128 in the VM's Security List/NSG (OCI Console → Networking →"
echo "Virtual Cloud Networks → your VCN → Security Lists → Add Ingress Rule,"
echo "source 0.0.0.0/0, destination port 20128) and in the OS firewall:"
echo "  sudo iptables -I INPUT -p tcp --dport 20128 -j ACCEPT (Oracle Linux/ufw allow 20128 on Ubuntu)"
