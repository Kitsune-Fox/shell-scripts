#!/bin/bash
# Script for backing up the Pi-hole v6 config using Teleporter

set -euo pipefail 

# Directory to place backup files
backup_directory="/path/to/pihole/backups"
backup_name="pihole-v6-backup-$(date -Id).zip"
backup_full_path="$backup_directory/$backup_name"

# Path to Pi-hole API password file
pihole_password_file="/path/to/pihole/api/password/file"

# Build Pi-hole API address
pihole_address="pihole.domain.com"
pihole_port=443
pihole_protocol="https"
pihole_api_url="$pihole_protocol://$pihole_address:$pihole_port/api"

# Create backup directory if it does not exist
mkdir -p "$backup_directory"

# Authenticate with the Pi-hole
auth_sid=$(curl -sS -X POST "$pihole_api_url/auth" \
 -H 'accept: application/json' \
 -H 'content-type: application/json' \
 -d '{"password":"'$(cat $pihole_password_file)'"}' \
 | jq -r '.session.sid') 

# Get the full backup using Teleporter
curl -sS -X GET "$pihole_api_url/teleporter" \
 -H 'accept: application/zip' \
 -H "sid: $auth_sid" \
 -o "$backup_full_path"

if [ -e "$backup_full_path" ]; then
    echo "Backup completed successfully"
else
    echo "Backup failed, you may wanna check on that"
fi
