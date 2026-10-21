#!/usr/bin/env bash

set -euo pipefail

THRESHOLD=60
EXPLAIN_MODE=false

if [[ "${1:-}" == "explain" ]]; then
  EXPLAIN_MODE=true
fi

get_cpu_usage() {
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle1=$((idle + iowait))

  sleep 1

  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  total2=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle2=$((idle + iowait))

  total_delta=$((total2 - total1))
  idle_delta=$((idle2 - idle1))

  if (( total_delta == 0 )); then
    echo 0
    return
  fi

  echo $(( (100 * (total_delta - idle_delta)) / total_delta ))
}

get_memory_usage() {
  free | awk '/Mem:/ { printf "%.0f", ($3 / $2) * 100 }'
}

get_disk_usage() {
  df --output=pcent / | awk 'NR==2 { gsub(/%/, "", $1); print $1 }'
}

cpu_usage=$(get_cpu_usage)
memory_usage=$(get_memory_usage)
disk_usage=$(get_disk_usage)

reasons=()

if (( cpu_usage > THRESHOLD )); then
  reasons+=("CPU utilization is ${cpu_usage}% (> ${THRESHOLD}%)")
fi

if (( memory_usage > THRESHOLD )); then
  reasons+=("Memory utilization is ${memory_usage}% (> ${THRESHOLD}%)")
fi

if (( disk_usage > THRESHOLD )); then
  reasons+=("Disk utilization is ${disk_usage}% (> ${THRESHOLD}%)")
fi

if (( ${#reasons[@]} == 0 )); then
  health_status="healthy"
else
  health_status="unhealthy"
fi

printf 'VM health: %s\n' "$health_status"

if [[ "$EXPLAIN_MODE" == true ]]; then
  printf 'CPU utilization: %s%%\n' "$cpu_usage"
  printf 'Memory utilization: %s%%\n' "$memory_usage"
  printf 'Disk utilization: %s%%\n' "$disk_usage"

  if [[ "$health_status" == "healthy" ]]; then
    printf 'Reason: CPU, memory, and disk utilization are all at or below %s%%.\n' "$THRESHOLD"
  else
    printf 'Reason(s):\n'
    for reason in "${reasons[@]}"; do
      printf -- '- %s\n' "$reason"
    done
  fi
fi
