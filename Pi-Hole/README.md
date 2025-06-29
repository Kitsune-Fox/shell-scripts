# Pi-hole v6 Helper Scripts

This repository contains Bash scripts to automate key tasks for managing a Pi-hole v6 instance:

- [**`pihole_v6_add_local_traefik_hosts.sh`**](#pihole_v6_add_local_traefik_hostssh) – Scrapes hostnames from Docker containers (Traefik labels) and syncs them to Pi-hole's DNS host configuration.
- [**`pihole_v6_backup.sh`**](#pihole_v6_backupsh) – Backs up the full Pi-hole v6 configuration using the built-in Teleporter API.

## Requirements

- Pi-hole v6 with API access enabled
- Docker installed and running
- `jq` installed (`sudo apt install jq`)
- Valid Pi-hole API password stored in a local file

---

## 🔐 Authentication

Scripts authenticate with the Pi-hole API using a password stored in a file:

```bash
# Example path to your password file
/path/to/pihole/api/password/file
```

This file should contain **only the raw password** (no quotes or extra characters).

**Ensure it is secure:**
```bash
chmod 600 /path/to/pihole/api/password/file
```

---

## 🛠 Scripts

### `pihole_v6_add_local_traefik_hosts.sh`

Scrapes Docker containers for `traefik.http.routers.*.rule` labels and updates Pi-hole's DNS `hosts` list.

- Extracts hostnames from Traefik rules (e.g., ``Host(`example.local`)``)
- Prepends a Docker host IP (detected or manually specified)
- Replaces outdated host-to-IP mappings in Pi-hole
- Sorts the entries alphabetically

#### Usage

```bash
./pihole_v6_add_local_traefik_hosts.sh
```

> ⚠️ Replace the following placeholders in the script before running:
`pihole_password_file="/path/to/pihole/api/password/file"`
`pihole_address="pihole.domain.com"`
`pihole_port=443`
`pihole_protocol="https"`

---

### `pihole_v6_backup.sh`

Fetches a full Teleporter backup of your Pi-hole v6 configuration.

- Authenticates with the API
- Saves backup ZIP to a specified local directory

#### Usage

```bash
./pihole_v6_backup.sh
```

> ⚠️ Replace the following placeholders in the script before running:
`backup_directory="/path/to/pihole/backups"`
`pihole_password_file="/path/to/pihole/api/password/file"`

Backups are saved as:
```
pihole-v6-backup-YYYY-MM-DD.zip
```

#### 🔧 Customization

##### Set a static IP (if needed):
In `pihole_v6_add_local_traefik_hosts.sh`:

```bash
# Automatically detect IP (default)
host_ip=$(ip -j route get 1.1.1.1 | jq -r '.[].prefsrc')

# Or set manually
# host_ip="192.168.0.123"
```

---

## ⚠️ Disclaimer

- These scripts are provided as-is for personal or internal use.
- Review them before deploying in production environments.
