#!/bin/sh
set -o errexit  # Exit on any statement returning non-true value.
set -o nounset  # Exit if an uninitialized variable is used.

# Update OpenWifiMap
#
# This is meant to be run on OpenWrt via cron-job.
#
# For now, registers a node with a single interface and a single
# neighbor only.
#
# Depends on olsrd-mod-nameservice and olsrd-mod-txtinfo.

version=2.0

# Tell'em who we are.
user_agent="openwifimap-update.sh/$version"
home="https://github.com/gitmo/freifunk/blob/master/openwifimap-update.sh"

# Set additional information in this file (start with a comma).
extra_fields="/etc/openwifimap_extra.json"

# Map services running OpenWifiMap
maphosts="api.openwifimap.net couch.pberg.freifunk.net/test/_design/owm-api/_rewrite"

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

# Query the txtinfo plugin for link quality.
quality=$(echo "/links" | nc localhost 2006 | awk /^$ip/'{ print $NR }')

for maphost in $maphosts
do

## Construct new document

[[ -f "$extra_fields" ]] && extras=$(cat "$extra_fields") || extras=""

json='{
  "type": "node",
  "hostname": "'$hostname'",
  "longitude": '$lon',
  "latitude": '$lat',
  "updateInterval": 3600,
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
  "freifunk:": {
     "contact": {
       "name": "'$(uci get freifunk.contact.nickname)'",
       "note": "'$(uci get freifunk.contact.note)'",
       "mail": "'$(uci get freifunk.contact.mail)'"
     }
  }'$extras',
  "script": "'$home'"
}'

length=$(/bin/echo -n "$json" | wc -c | tr -d ' ')

## Construct PUT request for netcat

# Split API URLs in host and resource parts at the first slash character
maphost="$maphost/"
host=${maphost%%/*}
base=${maphost#*/}

# HTTP header + data
request="\
PUT /$base/update_node/$hostname HTTP/1.1\r
User-Agent: $user_agent\r
Host: $host\r
Content-Length: $length\r
Content-Type: application/json\r
\r
$json"

## Update document in couchdb

# real netcat (not busybox) might need a delay: -i 1
/bin/echo -ne "$request" | nc $host 80

done
