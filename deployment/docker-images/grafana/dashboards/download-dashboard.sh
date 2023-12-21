#!/bin/bash
set -e

DASHBOARD_UID=$(curl -u ruegen:ruegen localhost:3000/api/search | jq -r '.[] | select(.title == "TM").uid')

curl -u ruegen:ruegen localhost:3000/api/dashboards/uid/$DASHBOARD_UID | jq .