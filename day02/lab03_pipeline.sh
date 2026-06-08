#!/bin/bash
# lab03_pipeline.sh — process log analysis pipeline
# Usage: ./lab03_pipeline.sh /path/to/access.log

LOG_FILE="${1:-/var/log/nginx/access.log}"

if [ ! -f "$LOG_FILE" ]; then
  echo "ERROR: Log file not found: $LOG_FILE" >&2
  exit 1
fi

echo "=== Log Analysis Report ==="
echo "File: $LOG_FILE"
echo "Total requests: $(wc -l < $LOG_FILE)"
echo ""
echo "=== Response Code Breakdown ==="
awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -rn
echo ""
echo "=== Top 5 IP Addresses ==="
awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -5
echo ""
echo "=== Top 5 Requested URLs ==="
awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -5
