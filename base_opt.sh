#!/system/bin/sh
# base_opt.sh
# Version 1.3
# 2026-11-24 @ 23:33 (UTC)
# ID: db4pd
# Do not steal
# Written by @jpzex (XDA & Telegram)
# with help of @InoCity, @GMnevs (Telegram)
# and AI tools like ChatGPT, Gemini and Fable
# (proper vibe coding is so real, guys)
# Use at your own risk! 

# Are you root?
[ "$(id -u)" -ne 0 ] && {
    echo "Run script as root." >&2
    exit 1
}

##### USER SET VARIABLES #####

# Dump mode (0 or 1): save a log file showing everything the script is meant to change. Check at the end of the script for more info.

dump=0

# Dry run mode (0 or 1): if dump=1, it will take note of everything that would change but won't apply anything.

dryrun=0

# Debug run (0 or 1): print on screen the duration of each script step. Even though it is completely independent from dryrun or dump, they make the script run slower so the timing will be delayed a few ms.

debug=0

##### DO NOT EDIT BELOW THIS LINE #####

#set -xv # debug

Changelog="
"
unset Changelog

scriptname=base_opt

# Generic optimizations.
# May not affect battery usage, just remove bottlenecks.

debug_run(){

TIME M1
TIME M2
TIME M4
TIME M5
TIME M8

}

main_opt(){

M1
M2
M4
M5
M8

}

#===================================================#

# Module 1: Reduce mountpoint overhead

M1(){
    local x mnt_dev mnt_path mnt_fs flags opt
    local mnt_list
    mnt_list="$(grep -E ' ext4 | f2fs ' /proc/mounts | grep -Ev ' ro,| /apex/|/storage/emulated' | awk '{print $1"&"$2"&"$3}' | sed 's/\/$//' | uniq)"

    for x in $mnt_list; do
        mnt_dev="${x%%&*}"
        mnt_path="${x#*&}"
        mnt_path="${mnt_path%&*}"
        mnt_fs="${x##*&}"

        mountpoint -q "$mnt_path" || continue

        case "$mnt_fs" in
            ext4)
                flags="commit=10"
                ;;
            f2fs)
                flags="flush_merge"
                ;;
            *)
                continue
                ;;
        esac
        for opt in $(printf '%s' "$flags" | tr ',' ' '); do
            wrcmd "mount -o remount,$opt $mnt_path" "awk -v m='$mnt_path' '\$2 == m {print; exit}' /proc/mounts"
        done

        if command -v fstrim >/dev/null 2>&1; then
            if [ "${dryrun:-0}" -eq 0 ]; then
                [ "${dump:-0}" -eq 1 ] && printf 'WRCMD - A: %s\nWRCMD - B: fstrim -v %s (async)\n\n' "$(df -h "$mnt_path" 2>/dev/null | tail -n 1)" "$mnt_path" >> "$dpath"
                ( fstrim -v "$mnt_path" >/dev/null 2>&1 ) &
            else
                if [ "${dump:-0}" -eq 1 ]; then
                    printf 'WRCMD - A: %s\nWRCMD - B: fstrim -v %s (dryrun)\n\n' "$(df -h "$mnt_path" 2>/dev/null | tail -n 1)" "$mnt_path" >> "$dpath"
                else
                    printf 'WRCMD - A: %s\nWRCMD - B: fstrim -v %s\n' "$(df -h "$mnt_path" 2>/dev/null | tail -n 1)" "$mnt_path"
                fi
            fi
        fi
    done
}

#===================================================#

# Module 2: Sysctl Tweaks (better network stability, decrease processing overhead and efficient memory usage)

M2(){
local sysctl_list='

# fs
fs.aio-max-nr = 262144
fs.pipe-max-size = 65536

# kernel
kernel.bpf_stats_enabled = 0
kernel.ftrace_dump_on_oops = 0
kernel.ftrace_enabled = 0
kernel.nohz_balance_kick = 0
kernel.perf_cpu_time_max_percent = 0
kernel.perf_event_max_sample_rate = 0
kernel.perf_event_max_stack = 0
kernel.perf_event_paranoid = 3
kernel.print-fatal-signals = 0
kernel.printk = 1 4 1 7
kernel.printk_delay = 0
kernel.printk_devkmsg = off
kernel.printk_ratelimit = 0
kernel.printk_ratelimit_burst = 0
kernel.sched_schedstats = 0
kernel.sched_tick_max_deferment = 2000000
kernel.sched_tunable_scaling = 1
kernel.sched_util_clamp_max = 1024
kernel.sched_util_clamp_min = 0
kernel.soft_watchdog = 0
kernel.timer_migration = 0
kernel.tracepoint_printk = 0

# net core
net.core.busy_read = 50
net.core.busy_poll = 50
net.core.dev_weight = 64
net.core.high_order_alloc_disable = 0
net.core.netdev_budget = 256
net.core.netdev_budget_usecs = 2500
net.core.somaxconn = 512

# net ipv4
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.ipfrag_max_dist = 128
net.ipv4.ipfrag_time = 3
net.ipv4.min_pmtu = 1400
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_autocorking = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_early_retrans = 2
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_fastopen = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_frto = 1
net.ipv4.tcp_keepalive_intvl = 20
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_low_latency = 0
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_no_metrics_save = 0
net.ipv4.tcp_orphan_retries = 4
net.ipv4.tcp_reordering = 5
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_syn_retries = 4
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1

# net netfilter
net.netfilter.nf_conntrack_acct = 0
net.netfilter.nf_conntrack_events = 0
net.netfilter.nf_conntrack_helper = 0
net.netfilter.nf_conntrack_log_invalid = 0
net.netfilter.nf_conntrack_tcp_timeout_established = 600

# VM
vm.block_dump = 0
vm.laptop_mode = 0
vm.oom_kill_allocating_task = 0
vm.oom_dump_tasks = 0
vm.panic_on_oom = 0
vm.stat_interval = 5
'

apply_sysctl() {
    local key val line k_path
    echo "$1" | while IFS= read -r line; do
        case "$line" in
            ""|\#*) continue ;;
        esac

        key="${line%%=*}"
        val="${line#*=}"

        key="${key#"${key%%[! ]*}"}"
        key="${key%"${key##*[! ]}"}"
        val="${val#"${val%%[! ]*}"}"
        val="${val%"${val##*[! ]}"}"

        k_path="/proc/sys/$(printf '%s' "$key" | tr '.' '/')"
        [ -e "$k_path" ] || continue

        wrc "$k_path" "$val"
    done
}

apply_sysctl "$sysctl_list"

}

#===================================================#

# Module 4: Improve transfer bandwidth and latency

M4(){

local x blocks skip

iotweak(){
    local q="$1/queue"
    local hw sc w_sched t_wait
    local max_sec="$2" nr_req="$3" ra_kb="$4" nomerge="$5" rq_aff="$6"

    if [ "$skip" -eq 1 ]; then
        if [ -r "$q/scheduler" ]; then
            read -r sc < "$q/scheduler"
            case "$sc" in
                *\[none\]*) return 0 ;;
            esac
            wrc "$q/scheduler" "none"
        fi
        return 0
    fi

    set_iosched() {
        case "$sc" in
            *"[$1]"*) ;;
            *) wrc "$q/scheduler" "$1" ;;
        esac
        w_sched="$q/iosched"
        t_wait=0
        while [ ! -d "$w_sched" ] && [ "$t_wait" -lt 10 ]; do
            sleep 0.01
            t_wait=$((t_wait + 1))
        done
    }

    if [ -r "$q/scheduler" ]; then
        read -r sc < "$q/scheduler"
        case "$sc" in
            *mq-deadline*)
                set_iosched "mq-deadline"
                wrc "$w_sched/fifo_batch" "16"
                wrc "$w_sched/front_merges" "1"
                wrc "$w_sched/read_expire" "250"
                wrc "$w_sched/write_expire" "3000"
                wrc "$w_sched/writes_starved" "10"
            ;;
            *bfq*)
                set_iosched "bfq"
                wrc "$w_sched/back_seek_max" "0"
                wrc "$w_sched/low_latency" "0"
                wrc "$w_sched/slice_idle" "0"
                wrc "$w_sched/quantum" "8"
                wrc "$w_sched/strict_guarantees" "0"
            ;;
            *cfq*)
                set_iosched "cfq"
                wrc "$w_sched/slice_idle" "0"
                wrc "$w_sched/back_seek_max" "1048576"
                wrc "$w_sched/back_seek_penalty" "1"
                wrc "$w_sched/fifo_expire_async" "2000"
                wrc "$w_sched/fifo_expire_sync" "200"
                wrc "$w_sched/low_latency" "0"
                wrc "$w_sched/target_latency" "250"
                wrc "$w_sched/group_idle" "0"
                wrc "$w_sched/slice_async" "2000"
                wrc "$w_sched/slice_async_rq" "1"
                wrc "$w_sched/slice_sync" "200"
                wrc "$w_sched/quantum" "8"
            ;;
            *deadline*)
                set_iosched "deadline"
                wrc "$w_sched/fifo_batch" "16"
                wrc "$w_sched/front_merges" "1"
                wrc "$w_sched/read_expire" "300"
                wrc "$w_sched/write_expire" "5000"
                wrc "$w_sched/writes_starved" "16"
            ;;
        esac
    fi

    if [ -r "$q/max_hw_sectors_kb" ]; then
        read -r hw < "$q/max_hw_sectors_kb"
        if [ -n "$hw" ] && [ "$max_sec" -le "$hw" ]; then
            wrc "$q/max_sectors_kb" "$max_sec"
        fi
    fi

    wrc "$q/nr_requests" "$nr_req"
    wrc "$q/read_ahead_kb" "$ra_kb"
    wrc "$q/nomerges" "$nomerge"
    wrc "$q/rq_affinity" "$rq_aff"
    wrc "$q/iostats" "0"
    wrc "$q/add_random" "0"
    wrc "$q/rotational" "0"
}

blocks="$(ls /sys/block 2>/dev/null | grep -E 'mmcblk|sd|loop|dm|zram')"

for x in $blocks; do
    [ -d "/sys/block/$x" ] || continue

    # iotweak <path> max_sectors_kb nr_requests read_ahead_kb nomerges rq_affinity
    case "$x" in
        mmcblk* )
            skip=0
            iotweak "/sys/block/$x" 512 128 256 1 0
        ;;
        sd* )
            skip=0
            iotweak "/sys/block/$x" 512 128 64 1 0
        ;;
        dm* | loop* )
            skip=1
            iotweak "/sys/block/$x" 1024 32 512 1 2
        ;;
        zram* )
            skip=1
            iotweak "/sys/block/$x" 64 8 0 2 2
        ;;
    esac
done

}

# Module 5: Kernel modules toggles

M5(){

local x inst sys

if [ -d "/sys/kernel/tracing" ]; then
    sys="/sys/kernel/tracing"
elif [ -d "/sys/kernel/debug/tracing" ]; then
    sys="/sys/kernel/debug/tracing"
else
    return 0
fi

wrc "$sys/tracing_on" "0"
wrc "$sys/trace" "0"
wrc "$sys/events/enable" "0"

if [ -d "$sys/instances" ]; then
    for x in "$sys"/instances/*; do
        [ -d "$x" ] || continue
        wrc "$x/tracing_on" "0"
        wrc "$x/events/enable" "0"
    done
fi

}

#===================================================#

# Module 8: SoC topology aware process and interrupt rescheduling

M8(){

# Step 1: SoC Topology Discovery

local cpu_base="/sys/devices/system/cpu"
local NC=0 CLUSTERS="" WEAK="" MID="" STRONG=""
local ECO_CORES="" MID_CORES="" POWER_CORES=""
local ECO_MASK="" MID_MASK="" POWER_MASK=""
local min_freq=0 max_freq=0 ONLINE_CPUS="" CPU_FREQS=""
local cpu cluster freq first_cpu prev_freq i=0

[ -d "$cpu_base" ] || return 0

local on_val
for cpu in "$cpu_base"/cpu[0-9]*; do
    [ -d "$cpu" ] || continue
    on_val=1
    [ -r "$cpu/online" ] && read -r on_val < "$cpu/online"
    [ "$on_val" = "1" ] && ONLINE_CPUS="${ONLINE_CPUS:+$ONLINE_CPUS }${cpu##*cpu}"
done

cluster="" freq=0 first_cpu=""
for cpu in $ONLINE_CPUS; do
    freq=0
    [ -r "$cpu_base/cpu$cpu/cpufreq/cpuinfo_max_freq" ] && read -r freq < "$cpu_base/cpu$cpu/cpufreq/cpuinfo_max_freq"
    case "$freq" in ''|*[!0-9]*) freq=0 ;; esac

    CPU_FREQS="$CPU_FREQS
$cpu $freq"

    if [ -z "$cluster" ]; then
        cluster="$cpu" ; prev_freq="$freq"
    elif [ "$freq" = "$prev_freq" ]; then
        cluster="$cluster $cpu"
    else
        CLUSTERS="${CLUSTERS:+$CLUSTERS
}$cluster"
        NC=$((NC + 1)) ; cluster="$cpu" ; prev_freq="$freq"
    fi
done
[ -n "$cluster" ] && CLUSTERS="${CLUSTERS:+$CLUSTERS
}$cluster" && NC=$((NC + 1))

if [ "$NC" -eq 1 ]; then
    WEAK="$CLUSTERS" ; STRONG="$CLUSTERS"
else
    OLDIFS="$IFS" ; IFS='
'
    i=0
    for cluster in $CLUSTERS; do
        first_cpu="${cluster%% *}"
        freq=$(echo "$CPU_FREQS" | grep "^$first_cpu " | cut -d' ' -f2)
        freq=${freq:-0}
        if [ "$i" -eq 0 ]; then
            min_freq="$freq" ; max_freq="$freq" ; WEAK="$cluster" ; STRONG="$cluster"
        else
            [ "$freq" -lt "$min_freq" ] && min_freq="$freq" && WEAK="$cluster"
            [ "$freq" -gt "$max_freq" ] && max_freq="$freq" && STRONG="$cluster"
        fi
        i=$((i + 1))
    done
    IFS="$OLDIFS"
fi

if [ "$NC" -ge 3 ]; then
    for cluster in $CLUSTERS; do
        [ "$cluster" != "$WEAK" ] && [ "$cluster" != "$STRONG" ] && MID="$cluster" && break
    done
fi

ECO_CORES="$WEAK"
MID_CORES="$MID"
POWER_CORES="${MID_CORES:+$MID_CORES }$STRONG"

[ -n "$ECO_CORES" ] && ECO_MASK="$(cpumask_hex "$ECO_CORES")"
[ -n "$POWER_CORES" ] && POWER_MASK="$(cpumask_hex "$POWER_CORES")"

# Fallback se a máscara falhar
[ -z "$POWER_MASK" ] && POWER_MASK="$ECO_MASK"
[ -z "$ECO_MASK" ] && return 0

# Step 2: Scheduler Infrastructure Topology Discovery

local HAS_CGROUP=0 HAS_CPUSET=0 HAS_UCLAMP=0 HAS_SCHEDTUNE=0 CGROUP_ROOT="" CPUSET_ROOT="" UCLAMP_ROOT="" STUNE_ROOT=""
local cg_root group probe

for cg_root in /sys/fs/cgroup /sys/fs/cgroup/cpu /sys/fs/cgroup/cpuset /dev/cpuctl /dev/cpuset; do
    [ -d "$cg_root" ] || continue
    if [ -z "$CGROUP_ROOT" ]; then
        for group in top-app foreground system background; do
            if [ -e "$cg_root/$group/cgroup.procs" ] || [ -e "$cg_root/$group/tasks" ]; then
                CGROUP_ROOT="$cg_root" ; HAS_CGROUP=1 ; break
            fi
        done
    fi
    if [ -z "$CPUSET_ROOT" ]; then
        for group in top-app foreground system background; do
            if [ -e "$cg_root/$group/cpuset.cpus" ]; then
                CPUSET_ROOT="$cg_root" ; HAS_CPUSET=1 ; break
            fi
        done
    fi
done

for probe in /dev/stune /sys/fs/cgroup/stune /sys/fs/cgroup/schedtune; do
    if [ -e "$probe/top-app/schedtune.boost" ]; then
        STUNE_ROOT="$probe" ; HAS_SCHEDTUNE=1 ; break
    fi
done

# Step 3: Process and Interrupt Priority Segregation

local PROCESS_TABLE POWER_PROCESS_PIDS="" ECO_PROCESS_PIDS=""
PROCESS_TABLE="$(ps -A -o PID= -o COMM= 2>/dev/null)"

[ -n "$PROCESS_TABLE" ] || return 0

local CRITICAL_RE='surfaceflinger|system_server|inputflinger|renderengine|hwcomposer|gpuservice|systemui|com.android.systemui|audioserver|cameraserver|mediaserver|drmserver|keystore2|lmkd|servicemanager|vold|zygote|zygote64'
local GRAPHICS_RE='mdss|dsi|drm|kgsl|kgsl_3d|gpu|adreno|display|panel|vsync|dpu|sde|mdp|touch|input|goodix|synaptics'
local MEDIA_RE='camera|cam_|csid|csiphy|vfe|jpeg|cpp|isp|msm_vidc|vidc|venus|video|encoder|decoder'
local POWER_PATTERNS="$CRITICAL_RE|$GRAPHICS_RE|$MEDIA_RE"
local ECO_PATTERNS='logd|statsd|traced|perfetto|dumpsys|bugreport|dex2oat|idmap2d|installd|mdnsd|wpa_supplicant'

POWER_PROCESS_PIDS="$(printf '%s\n' "$PROCESS_TABLE" | awk -v re="$POWER_PATTERNS" '$2 !~ /^\[/ && $2 ~ re {printf "%s ", $1}')"
ECO_PROCESS_PIDS="$(printf '%s\n' "$PROCESS_TABLE" | awk -v re="$ECO_PATTERNS" '$2 !~ /^\[/ && $2 ~ re {printf "%s ", $1}')"

# Step 4: Perform writes using variables produced on Steps 1-3

cgroup_add_pid(){
    local target="$1" target_pid="$2" file=""
    [ -n "$CGROUP_ROOT" ] || return 0
    if [ -e "$CGROUP_ROOT/$target/cgroup.procs" ]; then
        file="$CGROUP_ROOT/$target/cgroup.procs"
    elif [ -e "$CGROUP_ROOT/$target/tasks" ]; then
        file="$CGROUP_ROOT/$target/tasks"
    fi
    [ -n "$file" ] && wrs "$file" "$target_pid"
}

for pid in $POWER_PROCESS_PIDS; do
    [ -d "/proc/$pid" ] || continue
    cgroup_add_pid "foreground" "$pid"
    
    if command -v taskset >/dev/null 2>&1; then
        taskset -p "$POWER_MASK" "$pid" >/dev/null 2>&1
    fi
done

for pid in $ECO_PROCESS_PIDS; do
    [ -d "/proc/$pid" ] || continue
    cgroup_add_pid "background" "$pid"
    
    if command -v taskset >/dev/null 2>&1; then
        taskset -p "$ECO_MASK" "$pid" >/dev/null 2>&1
    fi
done

if [ "$HAS_CPUSET" -eq 1 ]; then
    local ALL_CPUS POWER_CPUS ECO_CPUS
    ALL_CPUS=$(printf '%s' "$ONLINE_CPUS" | tr ' ' ',')
    POWER_CPUS=$(printf '%s' "$POWER_CORES" | tr ' ' ',')
    ECO_CPUS=$(printf '%s' "$ECO_CORES" | tr ' ' ',')

    [ -n "$ALL_CPUS" ] && wrs "$CPUSET_ROOT/top-app/cpuset.cpus" "$ALL_CPUS"
    [ -n "$POWER_CPUS" ] && wrs "$CPUSET_ROOT/foreground/cpuset.cpus" "$POWER_CPUS"
    [ -n "$ECO_CPUS" ] && wrs "$CPUSET_ROOT/background/cpuset.cpus" "$ECO_CPUS"
fi

# Step 5: IRQ affinities

local IRQ_POWER_PATTERN='modem|thermal|charger|touch|ts_|input|mdss|dsi|drm|kgsl|gpu|adreno|display|vsync|dpu|camera|cam_|video'
local IRQ_ECO_PATTERN='wlan|wifi|ath|ipa|net|usb|ufs|mmc|sdhci|block|scsi|spi|i2c|uart|spmi|pmic'
local irq irq_power_list irq_eco_list

if [ -r "/proc/interrupts" ]; then
    irq_power_list="$(awk -v re="$IRQ_POWER_PATTERN" '$1 ~ /^[0-9]+:$/ && $0 ~ re {sub(/:/, "", $1); print $1}' /proc/interrupts)"
    irq_eco_list="$(awk -v re="$IRQ_ECO_PATTERN" '$1 ~ /^[0-9]+:$/ && $0 ~ re {sub(/:/, "", $1); print $1}' /proc/interrupts)"

    for irq in $irq_power_list; do
        [ -e "/proc/irq/$irq/smp_affinity" ] && wrs "/proc/irq/$irq/smp_affinity" "$POWER_MASK"
    done
    for irq in $irq_eco_list; do
        [ -e "/proc/irq/$irq/smp_affinity" ] && wrs "/proc/irq/$irq/smp_affinity" "$ECO_MASK"
    done
fi

# Step 6. Network RPS/XPS
local q
if [ -n "$ECO_MASK" ]; then
    for q in /sys/class/net/*/queues/rx-*; do
        [ -e "$q/rps_cpus" ] && wrs "$q/rps_cpus" "$ECO_MASK"
    done
    for q in /sys/class/net/*/queues/tx-*; do
        [ -e "$q/xps_cpus" ] && wrs "$q/xps_cpus" "$ECO_MASK"
    done
fi

# 7. Priority Boost

if command -v renice >/dev/null 2>&1; then
    for pid in $POWER_PROCESS_PIDS; do
        [ -d "/proc/$pid" ] && renice -n -10 -p "$pid" >/dev/null 2>&1
    done
    for pid in $ECO_PROCESS_PIDS; do
        [ -d "/proc/$pid" ] && renice -n 5 -p "$pid" >/dev/null 2>&1
    done
fi

}

#===================================================#

vars(){

local x
np=/dev/null
local marker="/data/lastrun_$scriptname"

if [ $dryrun -eq 0 ]; then touch "$marker"; date > "$marker"; fi
unset marker

# cluster calculator
local tc=0
for x in /sys/devices/system/cpu/cpu[0-9]*; do
    [ -d "$x" ] && tc=$((tc+1))
done

cpu_base="/sys/devices/system/cpu"

cl=""
local current_cluster prev_freq
local freq_file cur_freq
local i=0

while [ $i -lt "$tc" ]; do

    freq_file="$cpu_base/cpu$i/cpufreq/cpuinfo_max_freq"
    cur_freq=0

    if [ -r "$freq_file" ]; then
        read -r cur_freq < "$freq_file"
    fi
    [ -z "$cur_freq" ] && cur_freq=0

    if [ -z "$prev_freq" ]; then
        current_cluster="$i"
        prev_freq="$cur_freq"
    else
        if [ "$cur_freq" != "$prev_freq" ]; then

            if [ -z "$cl" ]; then
                cl="$current_cluster"
            else
                cl="$cl|$current_cluster"
            fi

            current_cluster="$i"
            prev_freq="$cur_freq"
        else
            current_cluster="$current_cluster $i"
        fi
    fi

    i=$((i+1))
done

if [ -n "$current_cluster" ]; then
    if [ -z "$cl" ]; then
        cl="$current_cluster"
    else
        cl="$cl|$current_cluster"
    fi
fi

# convert cpus to hex

cpumask_hex() {
        mask=0
        for c in $1; do
            bit=1
            i=0
            while [ "$i" -lt "$c" ]; do
                bit=$((bit * 2))
                i=$((i + 1))
            done
            mask=$((mask + bit))
        done
        printf "%x" "$mask"
    }

# check for uclamp support

[ -e /dev/cpuctl/top-app/cpu.uclamp.max ] && uc=1 || uc=0

#=DUMP=AND=DRY=RUN=START============================#

local have
local mode="${dump:-0}:${dryrun:-0}"

if [ "${dump:-0}" -eq 1 ]; then
    [ "${dryrun:-0}" -eq 0 ] && have="have" || have="have not"
    dpath="/data/$scriptname"
    for x in "$dpath"*; do
        [ -e "$x" ] && rm -f "$x"
    done
    dpath="$dpath-$(date +%Y-%m-%d).txt"
    printf 'The dump file is located in: %s. The values %s been applied because dryrun=%s.\n' "$dpath" "$have" "${dryrun:-0}"
fi

case "$mode" in
    0:0)
        wr() {
            if [ -e "$1" ]; then
                printf '%b\n' "$2" > "$1" 2>/dev/null || \
                    printf 'ERROR: writing %s to %s.\n' "$2" "$1" >&2
            fi
        }

        wrs() {
            if [ -e "$1" ]; then
                printf '%b\n' "$2" > "$1" 2>/dev/null
            fi
        }

        wrc() {
            local v
            if [ -e "$1" ] && [ -r "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                [ "$v" != "$2" ] && printf '%b\n' "$2" > "$1" 2>/dev/null
            fi
        }

        wrl() {
            if [ -e "$1" ]; then
                chmod 644 "$1" 2>/dev/null && \
                    printf '%b\n' "$2" > "$1" 2>/dev/null && \
                    chmod 444 "$1" 2>/dev/null
            fi
        }

        wrcmd() {
            eval "$1" >/dev/null 2>&1
        }
    ;;

    0:1)
        wr()  { [ -e "$1" ] && printf 'WR : %s > %s\n' "$2" "$1"; }
        wrs() { [ -e "$1" ] && printf 'WRS: %s > %s\n' "$2" "$1"; }
        wrc() { [ -e "$1" ] && printf 'WRC: %s > %s\n' "$2" "$1"; }
        wrl() { [ -e "$1" ] && printf 'WRL: %s > %s\n' "$2" "$1"; }

        wrcmd() {
            local v
            v=$(eval "$2" 2>/dev/null)
            printf 'WRCMD - A: %s\nWRCMD - B: %s\n' "$v" "$1"
        }
    ;;

    1:0)
        wr() {
            local v
            if [ -e "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                printf 'WR - A: %s = %s\nWR - B: %s = %s\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
                printf '%b\n' "$2" > "$1" 2>/dev/null || \
                    printf 'WR - ERROR writing %s to %s\n\n' "$2" "$1" >> "$dpath"
            fi
        }

        wrs() {
            local v
            if [ -e "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                printf 'WRS - A: %s = %s\nWRS - B: %s = %s\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
                printf '%b\n' "$2" > "$1" 2>/dev/null
            fi
        }

        wrc() {
            local v
            if [ -e "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                if [ "$v" != "$2" ]; then
                    printf 'WRC - A: %s = %s\nWRC - B: %s = %s\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
                    printf '%b\n' "$2" > "$1" 2>/dev/null
                else
                    printf 'WRC - A: %s = %s\nWRC - B: %s = %s (no write)\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
                fi
            fi
        }

        wrl() {
            local v
            if [ -e "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                printf 'WRL - A: %s = %s\nWRL - B: %s = %s\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
                chmod 644 "$1" 2>/dev/null && \
                    printf '%b\n' "$2" > "$1" 2>/dev/null && \
                    chmod 444 "$1" 2>/dev/null
            fi
        }

        wrcmd() {
            local v
            v=$(eval "$2" 2>/dev/null)
            printf 'WRCMD - A: %s\nWRCMD - B: %s\n\n' "$v" "$1" >> "$dpath"
            eval "$1" >/dev/null 2>&1 || \
                printf 'WRCMD - ERROR executing: %s\n\n' "$1" >> "$dpath"
        }
    ;;

    1:1)
        wr() {
            local v
            if [ -e "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                printf 'WR - A: %s = %s\nWR - B: %s = %s\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
            fi
        }

        wrs() {
            local v
            if [ -e "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                printf 'WRS - A: %s = %s\nWRS - B: %s = %s\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
            fi
        }

        wrc() {
            local v
            if [ -e "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                if [ "$v" != "$2" ]; then
                    printf 'WRC - A: %s = %s\nWRC - B: %s = %s\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
                else
                    printf 'WRC - A: %s = %s\nWRC - B: %s = %s (no write)\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
                fi
            fi
        }

        wrl() {
            local v
            if [ -e "$1" ]; then
                IFS= read -r v < "$1" 2>/dev/null
                printf 'WRL - A: %s = %s\nWRL - B: %s = %s\n\n' "$1" "$v" "$1" "$2" >> "$dpath"
            fi
        }

        wrcmd() {
            local v
            v=$(eval "$2" 2>/dev/null)
            printf 'WRCMD - A: %s\nWRCMD - B: %s\n\n' "$v" "$1" >> "$dpath"
        }
    ;;
esac

#=DUMP=AND=DRY=RUN=END==============================#

TIME() {
t=$(date +%s%3N)
"$@"
echo "$1: $((($(date +%s%3N)-t))) ms"
}

} # end vars

vars

if [ $debug -eq "1" ]; then
    debug_run
else
    main_opt
fi

unset scriptname dump dryrun have np