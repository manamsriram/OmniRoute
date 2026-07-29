# Oracle Cloud Free Tier Deploy

Runs OmniRoute on an Oracle Cloud **Always Free** VM instead of Render — real persistent
disk, real RAM, no card charges, no time limit. Fixes the Render free-tier issue where the
container was silently OOM/platform-killed (`Exited with status 128`, zero logs) before it
ever printed a line.

## 1. Provision the VM (console, one-time)

Console → Compute → Instances → **Create Instance**.

- **Shape**: `VM.Standard.A1.Flex` (Ampere ARM, Always Free pool — up to 4 OCPU / 24GB total
  across all your A1 instances). 2 OCPU / 8–12GB is plenty for a single-user OmniRoute
  instance and leaves headroom if you already have another Always Free VM running.
- **Image**: Ubuntu (latest LTS).
- **Add SSH key**: paste your public key (or generate one in the console and download the
  private key — you'll need it for both manual SSH and the GitHub Actions auto-redeploy).
- **Networking**: use an existing VCN or let it create one.
- Create.

Once running, note the VM's public IP.

**Open port 20128** (OCI Console → Networking → Virtual Cloud Networks → your VCN →
Security Lists → Default Security List → Add Ingress Rules: source `0.0.0.0/0`, TCP,
destination port `20128`). This is separate from the OS-level firewall — `oci-vm-setup.sh`
prints the `ufw`/`iptables` command for that side.

## 2. First-time VM setup

From your machine:

```bash
scp scripts/deploy/oci-vm-setup.sh ubuntu@<vm-ip>:~/
ssh ubuntu@<vm-ip> 'GHCR_OWNER=<your-github-username> bash ~/oci-vm-setup.sh'
```

This installs Docker, writes `/opt/omniroute/.env` (generated `JWT_SECRET`/`API_KEY_SECRET`,
default `INITIAL_PASSWORD=changeme` — **change it after first login**), writes
`~/omniroute-deploy.sh` (pull + restart script), and does the first `docker run`.

Verify: `curl http://<vm-ip>:20128/api/monitoring/health` or open it in a browser.

## 3. Auto-redeploy on new builds (optional)

`build-ghcr.yml` already builds a multi-arch (amd64 + arm64) image and, if these repo
secrets are set, SSHes into the VM and re-runs `~/omniroute-deploy.sh` after every push to
GHCR:

- `OCI_SSH_HOST` — the VM's public IP
- `OCI_SSH_USER` — `ubuntu` (or whatever the image's default user is)
- `OCI_SSH_KEY` — the **private** key matching the public key you added at VM creation

Set them: repo Settings → Secrets and variables → Actions → New repository secret. No
secrets set = the redeploy step is a no-op, everything else in the workflow runs the same.

## 4. Manual redeploy / rollback

```bash
ssh ubuntu@<vm-ip> 'bash ~/omniroute-deploy.sh'          # pulls latest-release, restarts
ssh ubuntu@<vm-ip> 'docker logs -f omniroute'             # tail logs
ssh ubuntu@<vm-ip> 'docker stop omniroute'                # stop
```

To pin a specific version instead of the floating `latest-release` tag, edit the `IMAGE`
line in `~/omniroute-deploy.sh` on the VM to `...:vX.Y.Z` and rerun it.

## 5. Data persistence

`/opt/omniroute/data` on the VM host is bind-mounted to `/app/data` in the container — this
is real disk on a real VM, so no Litestream/S3 replication needed (unlike the Render
free-tier disk-less problem this setup replaces).
