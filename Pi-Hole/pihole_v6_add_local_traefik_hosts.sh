#!/bin/bash
# Script to scrape Traefik Router Host tags from Docker containers and update the local host entries in Pi-hole v6

set -euo pipefail 

# Path to Pi-hole API password file
pihole_password_file="/path/to/pihole/api/password/file"

# Docker host address to use for the hostnames
# Get outbound if address
#host_ip=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
host_ip=$(ip -j route get 1.1.1.1 | jq -r '.[].prefsrc')
# Or statically assign address
# host_ip="192.168.0.123"

# Build Pi-hole API address
pihole_address="pihole.domain.com"
pihole_port=443
pihole_protocol="https"
pihole_api_url="$pihole_protocol://$pihole_address:$pihole_port/api"

# Authenticate with the Pi-hole
auth_sid=$(curl -sS -X POST "$pihole_api_url/auth" \
 -H 'accept: application/json' \
 -H 'content-type: application/json' \
 -d '{"password":"'$(cat $pihole_password_file)'"}' \
 | jq -r '.session.sid') 

# Fetch the existing config from Pi-hole and remove 'took'
existing_hosts_json=$(curl -sS -X GET "$pihole_api_url/config/dns%2Fhosts" \
 -H 'accept: application/json' \
 -H "sid: $auth_sid" \
 | jq 'del(.took)')

# Get hostnames from traefik docker labels and prepend IP
docker_host_list=$(docker ps -q | while read -r cid; do
  docker inspect "$cid" \
    | jq -r '.[0].Config.Labels 
        | to_entries[] 
        | select(.key | test("^traefik\\.http\\.routers\\..*\\.rule$")) 
        | .value' \
    | grep -oP 'Host\(`\K[^`]+'
done | sort -u | awk '{ print "'"$host_ip"'", $1 }')

# Update the JSON config
updated_hosts_json="$existing_hosts_json"

# Iterate through each IP/hostname pair, replacing existing entries with the same hostname if the IP differs, and append if new
while read -r line; do
  [ -z "$line" ] && continue

  ip=$(awk '{print $1}' <<< "$line")
  name=$(awk '{print $2}' <<< "$line")
  [ -z "$ip" ] || [ -z "$name" ] && continue

  # Check if exact entry exists (IP + hostname)
  exact_exists=$(echo "$updated_hosts_json" | jq -r --arg entry "$ip $name" '
    .config.dns.hosts[]? | select(. == $entry)
  ')

  if [ -z "$exact_exists" ]; then
    # Remove old entries that match the hostname (but not IP)
    updated_hosts_json=$(echo "$updated_hosts_json" | jq --arg name "$name" '
      .config.dns.hosts |= map(select((split(" ") | .[1]) != $name))
    ')

    # Add the new entry
    updated_hosts_json=$(echo "$updated_hosts_json" | jq --arg entry "$ip $name" '
      .config.dns.hosts += [$entry]
    ')
  fi
done <<< "$docker_host_list"

# Sort alphabetically by hostname (second field)
updated_hosts_json=$(echo "$updated_hosts_json" | jq '
  .config.dns.hosts |= sort_by(split(" ") | .[1])
')

# Output the final updated JSON
#echo "$updated_hosts_json" | jq .

# PATCH the updated JSON to the Pi-hole
patch_output=$(curl -sS -X PATCH "$pihole_api_url/config/dns%2Fhosts" \
 -H 'accept: application/json' \
 -H 'content-type: application/json' \
 -H "sid: $auth_sid" \
 -d "$updated_hosts_json")

# Output the PATCH output JSON
echo $patch_output | jq
