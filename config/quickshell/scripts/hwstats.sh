#!/usr/bin/env bash
# Machine-readable hardware stats for the system panel, one record per line:
#   temp|<chip>|<label>|<millidegrees>
#   gpu|<name>|<util %>|<mem used MiB>|<mem total MiB>|<temp °C>
for h in /sys/class/hwmon/hwmon*; do
    chip=$(<"$h/name")
    for f in "$h"/temp*_input; do
        [[ -r $f ]] || continue
        v=$(<"$f") 2>/dev/null || continue
        label=""
        [[ -r ${f%_input}_label ]] && label=$(<"${f%_input}_label")
        echo "temp|$chip|$label|$v"
    done
done

if command -v nvidia-smi >/dev/null; then
    # Don't wake a runtime-suspended NVIDIA card just to ask how idle it is
    dev=$(grep -l 0x10de /sys/bus/pci/devices/*/vendor 2>/dev/null | head -1)
    if [[ -z $dev || $(cat "${dev%/vendor}/power/runtime_status" 2>/dev/null) != suspended ]]; then
        nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu \
            --format=csv,noheader,nounits 2>/dev/null | head -1 |
            awk -F', ' '{ printf "gpu|%s|%s|%s|%s|%s\n", $1, $2, $3, $4, $5 }'
    else
        echo "gpu|NVIDIA (sleeping)|0|0|0|0"
    fi
else
    # AMD / Intel: the kernel's busy percentage
    for c in /sys/class/drm/card*/device/gpu_busy_percent; do
        [[ -r $c ]] && { echo "gpu|GPU|$(<"$c")|0|0|0"; break; }
    done
fi
