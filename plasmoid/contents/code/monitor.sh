#!/bin/bash
# PC Monitor — auto-discovers sensors across Linux laptops and desktops.
# Outputs KEY=VALUE lines parsed by the QML widget.

# Helper: normalize a string to a valid key suffix
norm() { echo "$1" | tr ' ()/.' '_' | tr -s '_' | sed 's/_$//'; }

# Read current CPU counters; diff against previous run (cached in /tmp) gives
# accurate load over the full 5-second polling interval with no sleep penalty.
CPU_CACHE="/tmp/pc-monitor-cpu.cache"
read -r cpu_now < /proc/stat

# ── BATTERY (first BAT* found) ─────────────────────────────────────────────
BAT_PATH=""
for b in /sys/class/power_supply/BAT*; do
    [ -d "$b" ] && BAT_PATH="$b" && break
done
if [ -n "$BAT_PATH" ]; then
    echo "HAS_BAT=1"
    { read -r v < "$BAT_PATH/cycle_count"; }       2>/dev/null && echo "CYCLES=$v"   || echo "CYCLES=0"
    { read -r v < "$BAT_PATH/capacity"; }          2>/dev/null && echo "CAPACITY=$v" || echo "CAPACITY=0"
    { read -r v < "$BAT_PATH/energy_full"; }       2>/dev/null && echo "EFULL=$v"    || echo "EFULL=0"
    { read -r v < "$BAT_PATH/energy_full_design"; } 2>/dev/null && echo "EDESIGN=$v" || echo "EDESIGN=0"
    { read -r v < "$BAT_PATH/status"; }            2>/dev/null && echo "STATUS=$v"   || echo "STATUS=Unknown"
    { read -r v < "$BAT_PATH/voltage_now"; }       2>/dev/null && echo "VOLTAGE=$v"  || echo "VOLTAGE=0"
fi

# ── SYSTEM ─────────────────────────────────────────────────────────────────
free -m | awk '/^Mem:/{print "RAMUSED=" $3; print "RAMTOTAL=" $2}'
awk '/^cpu MHz/{s+=$4;c++} END{printf "CPUFREQ=%.1f\n",s/c/1000}' /proc/cpuinfo

# ── HWMON auto-discovery ───────────────────────────────────────────────────
shopt -s nullglob

for h in /sys/class/hwmon/hwmon*; do
    [ -d "$h" ] || continue
    { read -r n < "$h/name"; } 2>/dev/null || continue
    [ -z "$n" ] && continue

    # ── CPU temperatures ──
    case "$n" in
        coretemp|k10temp|zenpower|k8temp)
            labels=("$h"/temp*_label)
            if [ ${#labels[@]} -gt 0 ]; then
                for f in "${labels[@]}"; do
                    base="${f%_label}"
                    { read -r lbl_raw < "$f"; }          2>/dev/null || continue
                    { read -r val < "${base}_input"; }   2>/dev/null || val=0
                    echo "CPUTEMP_$(norm "$lbl_raw")=${val}"
                done
            else
                { read -r val < "$h/temp1_input"; } 2>/dev/null && echo "CPUTEMP_Tdie=$val"
                { read -r val < "$h/temp2_input"; } 2>/dev/null && echo "CPUTEMP_Tccd1=$val"
            fi
            ;;

        # ── GPU temperatures ──
        amdgpu|radeon|nouveau|nvidia)
            labels=("$h"/temp*_label)
            if [ ${#labels[@]} -gt 0 ]; then
                for f in "${labels[@]}"; do
                    base="${f%_label}"
                    { read -r lbl_raw < "$f"; }          2>/dev/null || continue
                    { read -r val < "${base}_input"; }   2>/dev/null || val=0
                    echo "GPUTEMP_$(norm "$lbl_raw")=${val}"
                done
            else
                { read -r val < "$h/temp1_input"; } 2>/dev/null && echo "GPUTEMP_GPU=$val"
            fi
            ;;

        # ── Other sensors ──
        acpitz)
            { read -r val < "$h/temp1_input"; } 2>/dev/null && echo "OTHTEMP_ACPI=$val"
            ;;
        pch_*|pch)
            { read -r val < "$h/temp1_input"; } 2>/dev/null && echo "OTHTEMP_PCH=$val"
            ;;
        iwlwifi*|ath*|mt76*)
            { read -r val < "$h/temp1_input"; } 2>/dev/null && echo "OTHTEMP_WiFi=$val"
            ;;
        nvme*)
            { read -r val < "$h/temp1_input"; } 2>/dev/null && echo "OTHTEMP_NVMe_$(norm "$n")=$val"
            ;;
    esac

    # ── Fans (all hwmon nodes that expose fan*_input) ──
    for f in "$h"/fan*_input; do
        [ -f "$f" ] || continue
        fname="$(basename "$f")"
        idx="${fname#fan}"; idx="${idx%_input}"
        { read -r rpm < "$f"; } 2>/dev/null || rpm=0
        label_f="$h/fan${idx}_label"
        if [ -f "$label_f" ]; then
            { read -r raw < "$label_f"; } 2>/dev/null || raw="${n}_fan${idx}"
            echo "$raw" | grep -qE '^fan[0-9]*$' && lbl="${n}_${raw}" || lbl="$raw"
        else
            lbl="${n}_fan${idx}"
        fi
        echo "FAN_$(norm "$lbl")=${rpm}"
    done
done

# ── CPU load (diff /proc/stat across polling interval — no sleep, no self-pollution) ──
# /proc/stat line: cpu user nice system idle iowait irq softirq ...
if [ -f "$CPU_CACHE" ]; then
    read -r cpu_prev < "$CPU_CACHE"
    set -- $cpu_prev; u1=$2 n1=$3 s1=$4 i1=$5 w1=$6 r1=$7 f1=$8
    set -- $cpu_now;  u2=$2 n2=$3 s2=$4 i2=$5 w2=$6 r2=$7 f2=$8
    total1=$((u1+n1+s1+i1+w1+r1+f1))
    total2=$((u2+n2+s2+i2+w2+r2+f2))
    delta=$((total2-total1))
    didle=$((i2-i1))
    [ "$delta" -gt 0 ] && echo "CPULOAD=$(( (delta-didle)*100/delta ))" || echo "CPULOAD=0"
else
    echo "CPULOAD=0"
fi
echo "$cpu_now" > "$CPU_CACHE"
