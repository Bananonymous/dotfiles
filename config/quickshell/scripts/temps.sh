#!/usr/bin/env bash
# Show CPU (+RAM etc.) via lm_sensors and NVIDIA GPU via nvidia-smi.
echo "=== CPU / system (lm_sensors) ==="
sensors
echo
echo "=== NVIDIA GPU ==="
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total \
        --format=csv,noheader,nounits |
        awk -F', ' '{printf "%s: %s°C  util %s%%  mem %s/%s MiB\n", $1, $2, $3, $4, $5}'
else
    echo "nvidia-smi not found"
fi
