cat > README.md << 'DOCEOF'
# Self-Hosted Kubernetes Platform on a Segmented Network

A hands-on DevOps/SRE lab built entirely by hand across six Linux VMs: a
segmented VLAN network behind an nftables firewall, a k3s cluster running a
containerized Flask app backed by PostgreSQL, shared NFS storage, a full
CI/CD pipeline (Gitea + Jenkins with webhooks), a Prometheus/Grafana
observability stack, automated backups with tested restores, and a
default-deny security posture.

Everything was provisioned manually first, then the repeatable operations
(deploy, backup, restore, connectivity tests) were wrapped into scripts.

## Architecture

Six Ubuntu VMs (VirtualBox): one NAT/router gateway plus five segmented nodes.

| Node   | Role                          | mgmt IP    | Function VLAN IP    |
|--------|-------------------------------|------------|---------------------|
| gw     | NAT gateway, router, firewall | 10.0.10.1  | .1 on every VLAN    |
| master | k3s control plane (tainted)   | 10.0.10.10 | 10.0.20.10 (VLAN20) |
| node1  | k3s worker                    | 10.0.10.11 | 10.0.20.11 (VLAN20) |
| node2  | k3s worker                    | 10.0.10.12 | 10.0.20.12 (VLAN20) |
| db     | PostgreSQL on LVM             | 10.0.10.13 | 10.0.30.10 (VLAN30) |
| infra  | NFS, monitoring, CI/CD, ctrl  | 10.0.10.14 | 10.0.40.10 (VLAN40) |

Segments: mgmt (out-of-band SSH), VLAN 20 (app/k3s), VLAN 30 (db), VLAN 40
(ops). All inter-VLAN traffic routes through gw under a default-deny policy.

## What runs where

- **App:** Flask + Gunicorn, 2-replica k8s Deployment on the workers. Config
  via ConfigMap, DB password via Secret. Exposed externally via nftables DNAT
  on gw (double-NAT for asymmetric routing).
- **Database:** PostgreSQL on a dedicated LVM volume, listening only on its
  VLAN, pg_hba restricted to worker node IPs (SNAT-aware).
- **Storage:** NFS on infra as the PVC backend (static PV, RWX) and backup
  target.
- **CI/CD:** Gitea + Jenkins. git push -> webhook -> build -> transfer ->
  rolling update. Zero-downtime.
- **Observability:** Prometheus (pull), node_exporter everywhere,
  postgres_exporter on the DB, Grafana, Alertmanager.
- **Backup/DR:** nightly pg_dump (systemd timer) to NFS with retention, plus
  LVM snapshot. Restore is tested into a throwaway DB and verified.

## Security posture

- Network segmentation into four trust zones.
- Default-deny firewall: the forward chain drops everything except the
  explicit flows from the phase-0 communication matrix. The matrix became the
  ruleset; tests.sh verifies it (allow flows pass, deny flows blocked).
- Out-of-band SSH over mgmt only; key-only auth, no root, fail2ban.
- Least privilege: DB accepts 5432 only from worker IPs, never initiates
  outbound; secrets in k8s Secrets, not code.

## Scripts

| Script       | Runs on | What it does                                    |
|--------------|---------|-------------------------------------------------|
| deploy.sh    | infra   | image -> workers -> kubectl rollout (zero-DT)   |
| backup.sh    | db      | pg_dump | gzip -> NFS, timestamped, retention   |
| restore.sh   | db      | restore into a test DB and verify row count     |
| test.sh      | infra   | connectivity checks: allow pass, deny blocked   |

## Debugging stories

- **Masquerade not matching:** NAT saddr filter was the mgmt subnet, not the
  VLAN the traffic came from. Match on uplink oifname instead.
- **nftables "could not resolve hostname":** a quoted IP is read as a
  hostname. IPs unquoted; only interface names quoted.
- **netplan merge after cloning:** netplan merges all files in the dir; the
  clone's template config survived. Remove the cloud-init file.
- **PostgreSQL wouldn't start:** stray uncommented comment ("invalid line
  513"); the real unit is postgresql@14-main, not the postgresql.service
  wrapper; a root-owned data dir is rejected.
- **"password authentication failed" was good news:** it proved network +
  firewall + pg_hba all worked. The error type (refused/timeout/auth-failed)
  points at the broken layer.
- **Docker vs containerd:** k3s uses containerd; a docker build image is
  invisible until imported with k3s ctr images import.
- **Automation needs passwordless everything:** root-owned tar, running the
  script under sudo (wrong SSH keys), sudo in a non-interactive SSH (no TTY).
  Fix: chown, no sudo, NOPASSWD scoped to k3s/kubectl.
- **Disk exhaustion froze the CI node:** moved /var/lib/docker to a dedicated
  LVM volume.
- **Gitea SSRF protection blocked the webhook:** ALLOWED_HOST_LIST for the
  Jenkins IP. **Jenkins 401:** CSRF needs an API token in the webhook URL.
- **fstab locked the DB out of boot:** an NFS entry as type ext4 with no
  nofail/_netdev failed at boot -> emergency mode, sshd down. Fix: type nfs +
  nofail + _netdev.
- **A silently empty backup:** pg_dump under sudo from an unreadable dir
  produced an empty dump with exit 0, so pipefail missed it. The restore test
  caught it. A backup you haven't restored is a hope, not a backup.
- **DNAT needs a forward rule too:** under default-deny, DNAT rewrites the
  destination but doesn't permit the packet; the forward chain needs an
  explicit accept for the new destination.

## Key takeaways

- Design the communication matrix before touching a VM; it becomes both the
  firewall ruleset and the test suite.
- Manual-first builds understanding; scripts encode it afterward.
- The error type points straight at the broken layer.
- A backup isn't a backup until a restore has been tested.
- nofail + _netdev on every network filesystem in fstab, always.
DOCEOF
