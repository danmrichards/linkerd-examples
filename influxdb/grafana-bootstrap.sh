#!/bin/sh

influxdb_data_source=$(cat <<EOF
{
  "access": "proxy",
  "database":"l5d",
  "isDefault": true,
  "jsonData": {},
  "name": "influxdb",
  "type": "influxdb",
  "url": "http://localhost:8086"
}
EOF
)

until $(curl -sfo /dev/null http://127.0.0.1:3000/api/datasources); do
  # wait for grafana to boot
  sleep 1
done
curl -vX POST -d "${influxdb_data_source}" -H "Content-Type: application/json" http://127.0.0.1:3000/api/datasources
