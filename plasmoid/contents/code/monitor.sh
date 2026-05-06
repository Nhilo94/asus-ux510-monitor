#!/bin/bash
# PC Monitor — auto-discovers sensors across Linux laptops and desktops.
# Outputs KEY=VALUE lines parsed by the QML widget.

# ── BATTERY (first BAT* found) ─────────────────────────────────────────────
BAT_PATH=""
for b in /sys/class/power_supply/BAT*; do
    [ -d "$b" ] && BAT_PATH="$b" && break
done
if [ -n "$BAT_PATH" ]; then
    echo "HAS_BAT=1"
    echo "CYCLES=$(cat "$BAT_PATH/cycle_count" 2>/dev/null || echo 0)"
    echo "CAPACITY=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo 0)"
    echo "EFULL=$(cat "$BAT_PATH/energy_full" 2>/dev/null || echo 0)"
    echo "EDESIGN=$(cat "$BAT_PATH/energy_full_design" 2>/dev/null || echo 0)"
    echo "STATUS=$(cat "$BAT_PATH/status" 2>/dev/null || echo Unknown)"
    echo "VOLTAGE=$(cat "$BAT_PATH/voltage_now" 2>/dev/null || echo 0)"
fi

# ── SYSTEM ─────────────────────────────────────────────────────────────────
echo "CPULOAD=$(vmstat 1 2 | tail -1 | awk '{print 100-$15}')"
free -m | awk '/^Mem:/{print "RAMUSED=" $3; print "RAMTOTAL=" $2}'
echo "CPUFREQ=$(awk '/^cpu MHz/{sum+=$4; count++} END{printf "%.1f", sum/count/1000}' /proc/cpuinfo)"

# ── HWMON auto-discovery ───────────────────────────────────────────────────
shopt -s nullglob

for h in /sys/class/hwmon/hwmon*; do
    [ -d "$h" ] || continue
    n="$(cat "$h/name" 2>/dev/null)"
    [ -z "$n" ] && continue

    # Helper: normalize a string to a valid key suffix
    norm() { echo "$1" | tr ' ()/.' '_' | tr -s '_' | sed 's/_$//'; }

    # ── CPU temperatures ──
    case "$n" in
        coretemp|k10temp|zenpower|k8temp)
            labels=("$h"/temp*_label)
            if [ ${#labels[@]} -gt 0 ]; then
                for f in "${labels[@]}"; do
                    base="${f%_label}"
                    lbl="$(norm "$(cat "$f")")"
                    val="$(cat "${base}_input" 2>/dev/null || echo 0)"
                    echo "CPUTEMP_${lbl}=${val}"
                done
            else
                # Fallback for chips without label files
                [ -f "$h/temp1_input" ] && echo "CPUTEMP_Tdie=$(cat "$h/temp1_input")"
                [ -f "$h/temp2_input" ] && echo "CPUTEMP_Tccd1=$(cat "$h/temp2_input")"
            fi
            ;;

        # ── GPU temperatures ──
        amdgpu|radeon|nouveau|nvidia)
            labels=("$h"/temp*_label)
            if [ ${#labels[@]} -gt 0 ]; then
                for f in "${labels[@]}"; do
                    base="${f%_label}"
                    lbl="$(norm "$(cat "$f")")"
                    val="$(cat "${base}_input" 2>/dev/null || echo 0)"
                    echo "GPUTEMP_${lbl}=${val}"
                done
            else
                [ -f "$h/temp1_input" ] && echo "GPUTEMP_GPU=$(cat "$h/temp1_input")"
            fi
            ;;

        # ── Other sensors ──
        acpitz)
            [ -f "$h/temp1_input" ] && echo "OTHTEMP_ACPI=$(cat "$h/temp1_input")"
            ;;
        pch_*|pch)
            [ -f "$h/temp1_input" ] && echo "OTHTEMP_PCH=$(cat "$h/temp1_input")"
            ;;
        iwlwifi*|ath*|mt76*|rtw*)
            [ -f "$h/temp1_input" ] && echo "OTHTEMP_WiFi=$(cat "$h/temp1_input")"
            ;;
        nvme*)
            [ -f "$h/temp1_input" ] && echo "OTHTEMP_NVMe_$(norm "$n")=$(cat "$h/temp1_input")"
            ;;
    esac

    # ── Fans (all hwmon nodes that expose fan*_input) ──
    for f in "$h"/fan*_input; do
        [ -f "$f" ] || continue
        fname="$(basename "$f")"
        idx="${fname#fan}"; idx="${idx%_input}"
        rpm="$(cat "$f" 2>/dev/null || echo 0)"
        label_f="$h/fan${idx}_label"
        if [ -f "$label_f" ]; then
            raw="$(cat "$label_f")"
            # Prefix generic labels (e.g. "fan1") with hwmon name
            if echo "$raw" | grep -qE '^fan[0-9]*$'; then
                lbl="${n}_${raw}"
            else
                lbl="$raw"
            fi
        else
            lbl="${n}_fan${idx}"
        fi
        echo "FAN_$(norm "$lbl")=${rpm}"
    done
done
