#!/bin/sh

# Update OpenWifiMap
#
# This is meant to be run on OpenWrt via cron-job.
#
# For now, registers a node with a single interface and a single
# neighbor only.
#
# Depends on olsrd-mod-nameservice and olsrd-mod-txtinfo.

set -o errexit  # Exit on any statement returning non-true value.
set -o nounset  # Exit if an uninitialized variable is used.

# Set additional information in this file (start with a comma).
extra_fields="/etc/openwifimap_extra.json"

# Map services running OpenWifiMap
maphosts="openwifimap.net map.pberg.freifunk.net"
db="openwifimap"

# These files are updated by the olsr nameservice plugin.
latlon_file=$(uci get olsrd.olsrd_nameservice.latlon_file)
hosts_file=$(uci get olsrd.olsrd_nameservice.hosts_file)

## Parse our IP, location and gateway from nameserver plugin.

# One special Node() entry for this node
#   defroute means: The current neighbour IP for 0.0.0.0/0
# Self('mainip',lat,lon,defhna?1:0,'defroute','name');
set -- $(awk -F "[',]" '/Self/ { print $2,$4,$5,$8,$11 }' < $latlon_file)
ip=$1; lat=$2; lon=$3; defroute=$4; hostname=$5.olsr

# For now, only the neighbor with the default route is supported.
neighbor=$(awk /^$defroute/'{ print $2 }' < $hosts_file)

# Query the txtinfo-plugin for link quality.
quality=$(echo "/links" | nc localhost 2006 | awk /^$ip/'{ print $NR }')

for maphost in $maphosts
do

## Get revision id of the document for this node

url="http://$maphost/$db/$hostname"
_rev=$(wget -O - "$url" 2>/dev/null | tr \" \\n | grep _rev -A 2 | tail -1)

## Construct new document

[[ -f "$extra_fields" ]] && extras=$(cat "$extra_fields") || extras=""

json='{
  "_id": "'$hostname'",
  "_rev": "'$_rev'",
  "type": "node",
  "hostname": "'$hostname'",
  "longitude": '$lon',
  "latitude": '$lat',
  "interfaces": [
    {
      "name": "'$hostname'",
      "ipv4Addresses": ["'$ip'"]
    }
  ],
  "neighbors": [
    {
      "interface": "'$hostname'",
      "id": "'$neighbor'",
      "quality": '$quality'
    }
  ],
  "ipv4defaultGateway": "'$defroute'",
  "contact": {
    "name": "'$(uci get freifunk.contact.nickname)'",
    "note": "'$(uci get freifunk.contact.note)'",
    "mail": "'$(uci get freifunk.contact.mail)'"
  }'$extras'
}'

length=$(/bin/echo -n "$json" | wc -c | tr -d ' ')

## Contruct PUT request for netcat

request="PUT /$db/$hostname HTTP/1.1
User-Agent: nc
Host: $maphost
Content-Type: application/json
Content-Length: $length

$json"

## Update document in couchdb
# real netcat (not busybox) might need a delay: -i 1
/bin/echo -n "$request" | nc $maphost 80

done
