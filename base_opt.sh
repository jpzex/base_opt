# base_opt.sh
# Version 1.2.2
# 2026-03-23 @ 18:50 (UTC)
# ID: b2ij3
# Do not steal
# Written by @jpzex (XDA & Telegram)
# with help of @InoCity (Telegram)
# and ChatGPT (proper vibe coding is so real, guys)
# Use at your own risk!

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
Version: 1.2.2
- M1: changed filtering rules and command args for improved execution speed and proper mount point selection
- M1: removed erofs flags because fs is always RO
- M2: moved some sysctl keys to batt/game due to script philosophy misalignment
- M2: improved reliability of the value setting function
- M8: changed selection of threads/processes to get cpuset to power cores to ensure proper load balancing
- M8: prevent background process boosting
"
unset Changelog

scriptname=base_opt

# Generic optimizations.
# May not affect battery usage, just remove bottlenecks.

debug_run(){

TIME M1
TIME M2
TIME M4
TIME M8

}

main_opt(){

M1
M2
M4
M8

}

#===================================================#

# Module 1: Reduce overhead with new mount options 

M1(){
local flags x mnt_list mnt_dev mnt_path mnt_fs 
if [ $dryrun -eq 0 ]; then
    mnt_list="$(grep -E ' ext4 | f2fs ' /proc/mounts | grep -Ev ' ro,| /apex/|/storage/emulated/0' | awk '{print $1"&"$2"&"$3}' | sed 's/\/$//' | uniq)"
    for x in $mnt_list; do
        IFS='&' read -r mnt_dev mnt_path mnt_fs <<< "$x" 
        mountpoint -q "$mnt_path" || continue
        case "$mnt_fs" in
            ext4 )
                flags=commit=10 ;;
            f2fs )
                flags=flush_merge,background_gc=on ;;
            * )
                continue ;;
        esac
        mount -o remount,noatime,nodiratime,$flags "$mnt_path"
        command -v fstrim > "$np" && fstrim "$mnt_path"
    done
fi
}

#===================================================#

# Module 2: Sysctl Tweaks for better memory management and improved networking bandwidth and stability

M2(){
local key val
local sysctl_list='

# FS
fs.aio-max-nr = 262144
fs.epoll.max_user_watches = 32768
fs.inotify.max_user_watches = 262144
fs.inotify.max_user_instances = 512
fs.mount-max = 100000

# Kernel
kernel.bpf_stats_enabled = 0
kernel.ctrl-alt-del = 0
kernel.dmesg_restrict = 1
kernel.ftrace_dump_on_oops = 0
kernel.hung_task_timeout_secs = 120
kernel.perf_cpu_time_max_percent = 1
kernel.perf_event_max_sample_rate = 1
kernel.perf_event_paranoid = 3
kernel.print-fatal-signals = 0
kernel.printk = 1 1 1 1
kernel.printk_delay = 0
kernel.printk_devkmsg = off
kernel.printk_ratelimit = 0
kernel.printk_ratelimit_burst = 0
kernel.sched_autogroup_enabled = 1
kernel.sched_force_lb_enable = 0
kernel.sched_schedstats = 0
kernel.sched_tunable_scaling = 1
kernel.sched_util_clamp_max = 1024
kernel.sched_util_clamp_min = 0
kernel.soft_watchdog = 1
kernel.softlockup_panic = 0
kernel.tracepoint_printk = 0
kernel.warn_limit = 100
kernel.watchdog = 1

# Net core
net.core.busy_read = 0
net.core.busy_poll = 0
net.core.dev_weight = 64
net.core.high_order_alloc_disable = 0
net.core.netdev_budget = 300
net.core.netdev_budget_usecs = 4000
net.core.somaxconn = 512

# Net IPv4 behavior
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.ipfrag_max_dist = 128
net.ipv4.ipfrag_time = 3
net.ipv4.min_pmtu = 1400
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_autocorking = 1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_early_retrans = 2
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_fack = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_frto = 1
net.ipv4.tcp_keepalive_intvl = 20
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_low_latency = 0
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_mtu_probing = 2
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

# Netfilter behavior
net.netfilter.nf_conntrack_acct = 0
net.netfilter.nf_conntrack_events = 0
net.netfilter.nf_conntrack_helper = 0
net.netfilter.nf_conntrack_log_invalid = 0
net.netfilter.nf_conntrack_tcp_timeout_established = 600

# VM (non-memory steering)
vm.block_dump = 0
vm.laptop_mode = 0
vm.oom_kill_allocating_task = 0
vm.oom_dump_tasks = 0
vm.panic_on_oom = 0
vm.stat_interval = 10
'

apply_sysctl() {
echo "$1" | while IFS= read -r line; do
    case "$line" in
        ""|\#*) continue ;;
    esac
    key=${line%%=*}
    val=${line#*=}
    key=$(echo "$key" | awk '{$1=$1;print}')
    val=$(echo "$val" | awk '{$1=$1;print}')
    key=${key//./\/}
    wrs "/proc/sys/$key" "$val"
done
}

apply_sysctl "$sysctl_list"

}

#===================================================#

# Module 4: Storage devices tweaks to decrease overhead, improve transfer bandwidth and latency

M4(){

local x skip

iotweak(){
local q w hw
q=$1/queue
w="wrc $q"

read hw < $q/max_hw_sectors_kb
if [ $3 -le $hw ]; then
    $w/max_sectors_kb $3; fi      # 128 default
    $w/nr_requests $4              # 128 default
    $w/read_ahead_kb $5            # 128 default
    $w/nomerges $6                 # 0 merge, 1 simple only, 2 nomerge
    $w/rq_affinity $7              # 1 group, 2 core
    $w/iostats 0                   # decrease overhead
    $w/add_random 0                # help create randomness
    $w/rotational 0                 # 0 flash, 1 hdd
    
    [ $8 -eq 1 ] && return

    w="wrs $q/iosched"
    read sc < $q/scheduler
    case "$sc" in
    
    *mq-deadline*)
        wr $q/scheduler mq-deadline
        $w/fifo_batch 32
        $w/front_merges 1
        $w/read_expire 500
        $w/write_expire 5000
        $w/writes_starved 16
    ;;
    
    *cfq*)
        wr $q/scheduler cfq
        $w/slice_idle 0
        $w/back_seek_max 1048576
        $w/back_seek_penalty 1
        $w/fifo_expire_async 2000
        $w/fifo_expire_sync 200
        $w/low_latency 0
        $w/target_latency 250
        $w/group_idle 0
        $w/slice_async 2000
        $w/slice_async_rq 1
        $w/slice_sync 200
        $w/quantum 8
    ;;
    
    *deadline*)
        wr $q/scheduler deadline
        $w/fifo_batch 32
        $w/front_merges 1
        $w/read_expire 500
        $w/write_expire 5000
        $w/writes_starved 16
    ;;

    *bfq*)
        wr $q/scheduler bfq
        $w/back_seek_max 0
        $w/low_latency 0
        $w/slice_idle 0
        $w/quantum 8
        $w/strict_guarantees 0
    ;;

    esac
}

local blocks="$(ls /sys/block | grep -E 'mmcblk|sd|loop|dm')"
for x in $blocks; do
case /sys/block/$x in
    /sys/block/mmcblk* )
        # Usually MicroSD or internal EMMC
        skip=0
        iotweak /sys/block/$x mq-deadline 128 64 32 0 2 $skip
    ;;
    /sys/block/sd* )
        # Usually UFS partitions
        skip=0
        iotweak /sys/block/$x mq-deadline 512 256 256 0 2 $skip
    ;;
    /sys/block/dm* | /sys/block/loop* )
        # encrypted and/or logical partitions
        skip=1
        iotweak /sys/block/$x none 256 128 256 1 2 $skip
    ;;
esac
done

}

#===================================================#

# Module 8: Dynamic SoC aware task scheduling optimization
M8(){

# detect clusters separated by |

local NC=0
local CLUSTERS=""

local c
OLDIFS="$IFS"
IFS='|'
for c in $cl; do
    if [ -z "$CLUSTERS" ]; then
    CLUSTERS="$c"
else
    CLUSTERS="$CLUSTERS
$c"
fi
    NC=$((NC+1))
done
IFS="$OLDIFS"

local WEAK=""
local STRONG=""
local MID=""
local min_freq=0
local max_freq=0

local i=0
local x
OLDIFS="$IFS"
IFS='
'
for x in $CLUSTERS; do
    local first_cpu="${x%% *}"
    local freq=0
    if [ -r "$cpu_base/cpu$first_cpu/cpufreq/cpuinfo_min_freq" ]; then
        read -r freq < "$cpu_base/cpu$first_cpu/cpufreq/cpuinfo_min_freq"
    fi
    [ -z "$freq" ] && freq=0

    if [ $i -eq 0 ]; then
        min_freq=$freq
        max_freq=$freq
        WEAK="$x"
        STRONG="$x"
    else
        if [ "$freq" -lt "$min_freq" ]; then
            min_freq=$freq
            WEAK="$x"
        fi

        if [ "$freq" -gt "$max_freq" ]; then
            max_freq=$freq
            STRONG="$x"
        fi
    fi

    i=$((i+1))
done

IFS="$OLDIFS"

if [ "$NC" -ge 3 ]; then
OLDIFS="$IFS"
IFS='
'
for x in $CLUSTERS; do
    if [ "$x" != "$WEAK" ] && [ "$x" != "$STRONG" ]; then
        MID="$x"
        break
    fi
done
IFS="$OLDIFS"
fi

local POWER_MASK
local ECO_MASK=$(cpumask_hex "$WEAK")

if [ -z "$MID" ]; then
    POWER_MASK=$(cpumask_hex "$MID $STRONG")
    else
    POWER_MASK=$(cpumask_hex "$STRONG")
fi

# Workqueue containment to WEAK cores

local wq
for wq in /sys/devices/virtual/workqueue/*; do
    [ -e "$wq/cpumask" ] && wrs "$wq/cpumask" $ECO_MASK
done

# IRQ affinity
local cacheirq="$(cat /proc/interrupts)"
set_irq_mask(){
    local irq
    for irq in $(echo "$cacheirq" | grep -iE "$1" | awk '{print $1}' | tr -d ':'); do
        wrs /proc/irq/$irq/smp_affinity "$2"
    done
}

# WLAN, storage and background / IO IRQs to ECO_MASK
local IRQ_ECO_PATTERN="wlan|wifi|WLAN_CE|cnss|ath|ipa|qcawifi|rmnet|net|usb|ufs|mmc|sdhci|block|scsi|sdio|glink|glink-native|smp2p|ipcc|modem|bam|qmi|ufshcd|spi|spi_geni|i2c|i2c_geni|i3c|serial|serial_geni|uart|geni|dwc3|xhci|ehci|phy|pcie|nvme|swr|swr_master|slim|spmi|pmic|pmic_arb|adc|tsens|thermal|charger|battery|rtc|pon|bcl|wdog|ipa_dma|ipa_tx|ipa_rx|msmgpio|gpio|sde_rotator"
set_irq_mask "$IRQ_ECO_PATTERN" "$ECO_MASK"

# Touch, display and high throughput / latency sensitive IRQs to POWER_MASK
# IRQ_POWER_PATTERN="touch|ts_|chipone|input|goodix|synaptics|fts|mdss|dsi|dsi_ctrl|drm|kgsl|kgsl_3d|gpu|3d|adreno|display|panel|vsync|crtc|rot|rotator|sec_touch|dpu|sde|mdp|msm_vidc|vidc|venus|video|encoder|decoder|camera|cam_|csid|csiphy|tfe|ope|cci|vfe|jpeg|cpp|isp"
# set_irq_mask "$IRQ_POWER_PATTERN" "$POWER_MASK"

IRQ_POWER_PATTERN="touch|ts_|chipone|input|goodix|synaptics|fts|mdss|dsi|dsi_ctrl|drm|kgsl|kgsl_3d|gpu|3d|adreno|display|panel|vsync|crtc|rot|rotator|sec_touch|dpu|sde|mdp|msm_vidc|vidc|venus|video|encoder|decoder|camera|cam_|csid|csiphy|tfe|ope|cci|vfe|jpeg|cpp|isp"
set_irq_mask "$IRQ_POWER_PATTERN" "$POWER_MASK"

local fg_procs

for x in "$(ps -A -o name | grep -E 'touch|ts_|chipone|input|goodix|synaptics|fts|mdss|dsi|dsi_ctrl|drm|kgsl|kgsl_3d|gpu|3d|adreno|display|panel|vsync|crtc|rot|rotator|sec_touch|dpu|sde|mdp|msm_vidc|vidc|venus|video|encoder|decoder|camera|cam_|csid|csiphy|tfe|ope|cci|vfe|jpeg|cpp|isp' | grep -Ev '\[' )"; do
fg_procs+=" $x"; done

return

# RPS / XPS to ECO_MASK
local q
for q in /sys/class/net/*/queues/rx-*; do
    wrs $q/rps_cpus "$ECO_MASK"
    wrs  $q/rps_flow_cnt 4096
done

for q in /sys/class/net/*/queues/tx-*; do
    wrs $q/xps_cpus "$ECO_MASK"
done

# UCLAMP Scheduling Policy

local CG=/dev/cpuctl

[ ! -d "$CG" ] && return

if [ "$uc" = "1" ]; then

    # Top-app (foreground) unrestricted with high priority
    wrs "$CG/top-app/cpu.uclamp.min" "0"
    wrs "$CG/top-app/cpu.uclamp.max" "1024"
    wrs "$CG/top-app/cpu.uclamp.latency_sensitive" "1"
    wrs "$CG/top-app/cpu.uclamp.sched_boost_no_override" "0"

    # Critical foreground limited to 75% but latency sensitive
    wrs "$CG/foreground/cpu.uclamp.min" "0"
    wrs "$CG/foreground/cpu.uclamp.max" "768"
    wrs "$CG/foreground/cpu.uclamp.latency_sensitive" "1"
    wrs "$CG/foreground/cpu.uclamp.sched_boost_no_override" "0"

    # System moderate, not latency sensitive
    wrs "$CG/system/cpu.uclamp.min" "0"
    wrs "$CG/system/cpu.uclamp.max" "512"
    wrs "$CG/system/cpu.uclamp.latency_sensitive" "0"
    wrs "$CG/system/cpu.uclamp.sched_boost_no_override" "1"

    # Non-critical background restricted and not latency sensitive
    for g in background system-background; do
        wrs "$CG/$g/cpu.uclamp.min" "0"
        wrs "$CG/$g/cpu.uclamp.max" "512"
        wrs "$CG/$g/cpu.uclamp.latency_sensitive" "0"
        wrs "$CG/$g/cpu.uclamp.sched_boost_no_override" "1"
    done

    # Camera / NNAPI / dex2oat: burst-friendly and latency sensitive
    for g in camera-daemon nnapi-hal dex2oat; do
        wrs "$CG/$g/cpu.uclamp.min" "0"
        wrs "$CG/$g/cpu.uclamp.max" "960"
        wrs "$CG/$g/cpu.uclamp.latency_sensitive" "1"
        wrs "$CG/$g/cpu.uclamp.sched_boost_no_override" "0"
    done
fi

# UI related critical Android processes

local CRITICAL_PROCS="
audioserver
cameraserver
com.android.systemui
drmserver
gpuservice
hwcomposer
hwservicemanager
init
inputflinger
keystore2
lmkd
logd
mediaserver
renderengine
servicemanager
statsd
surfaceflinger
system_server
systemui
tombstoned
ueventd
vold
zygote
zygote64
"

local pname pid

for pname in $CRITICAL_PROCS; do
    for pid in "$(pidof $pname 2>/dev/null)"; do
        [ -z "$pid" ] && continue
        renice -n -15 -p $pid > $np 2>&1
        #taskset -p $POWER_MASK $pid > $np 2>&1

        if [ "$uc" = "1" ]; then
            CG=/dev/cpuctl
            if [ -e "$CG/foreground/tasks" ]; then
                wrs "$CG/foreground/tasks" $pid
            fi
        fi
    done
done
for pid in "$fg_procs"; do
        [ -z "$pid" ] && continue
        renice -n -10 -p $pid > $np 2>&1
        #taskset -p $POWER_MASK $pid > $np 2>&1

        if [ "$uc" = "1" ]; then
            CG=/dev/cpuctl
            if [ -e "$CG/foreground/tasks" ]; then
                wrs "$CG/foreground/tasks" $pid
            fi
        fi
done

# limit background
wrc /dev/stune/background/schedtune.prefer_idle 0
wrc /dev/stune/background/schedtune.boost -10

}

#===================================================#

vars(){

local x
np=/dev/null
local marker="/data/lastrun_$scriptname"

if [ $dryrun -eq 0 ]; then touch $marker; echo $(date) > $marker; fi
unset marker

# cluster calculator
local tc=0
for x in /sys/devices/system/cpu/cpu[0-9]*; do
    [ -d "$x" ] && tc=$((tc+1))
done

cpu_base="/sys/devices/system/cpu"

cl=""
local current_cluster prev_min_freq
local i=0

while [ $i -lt "$tc" ]; do

    freq_file="$cpu_base/cpu$i/cpufreq/cpuinfo_min_freq"
    min_freq=0

    if [ -r "$freq_file" ]; then
        read -r min_freq < "$freq_file"
    fi
    [ -z "$min_freq" ] && min_freq=0

    if [ -z "$prev_min_freq" ]; then
        current_cluster="$i"
        prev_min_freq="$min_freq"
    else
        if [ "$min_freq" != "$prev_min_freq" ]; then

            if [ -z "$cl" ]; then
                cl="$current_cluster"
            else
                cl="$cl|$current_cluster"
            fi

            current_cluster="$i"
            prev_min_freq="$min_freq"
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
    local mask=0
    local c
    for c in $1; do
        mask=$((mask | (1 << c)))
    done
    printf "%x" "$mask"
}

# check for uclamp support

[ -e /dev/cpuctl/top-app/cpu.uclamp.max ] && uc=1 || uc=0

readf(){ [ -e "$1" ] && cat "$1"; }

search(){ readf "$2" | grep "$1" > $np; }

# search <string> <file>
# searches for string in file if it exists and returns
# just an error code, 0 (true) for "string found" or 
# 1 (false) for "not found". Does not print.

#=DUMP=AND=DRY=RUN=START============================#

local have

if [ "$dryrun" -eq 0 ]; then
    have="have"

wr(){
    [ -e "$1" ] && echo -e "$2" > "$1" || \
    echo "ERROR: Cannot write $2 to $1."
}

wrs(){ # silent wr
    if [ -e "$1" ]; then
        echo -e "$2" > "$1" 2>&1
    fi
}

wrc(){ # silently writes if current value is different from new
if [ -e "$1" ]; then
v=$(cat "$1")
[ "$v" != "$2" ] && echo -e "$2" > "$1" 2>&1
fi
}

wrl(){ # unlock, write, lock
    [ -e "$1" ] && chmod 666 "$1" && \
    echo -e "$2" > "$1" && chmod 444 "$1"
}

else
    have="have not"
    wr(){ [ -e "$1" ] && echo -e "WR : $2 > $1"; }
    wrl(){ [ -e "$1" ] && echo -e "WRL: $2 > $1"; }
    wrs(){ [ -e "$1" ] && echo -e "WRS: $2 > $1"; }
fi

# start dump

if [ "$dump" -eq "1" ]; then
    dpath=/data/$scriptname
    for x in $dpath*; do
        [ -e "$x" ] && rm "$x"
    done
    dpath="$dpath-$(date +%Y-%m-%d).txt"
    echo "The dump file is located in: $dpath. The values $have been applied because dryrun=$dryrun."

    wr(){
    if [ "$dump" -eq 1 ]; then
        if [ -e "$1" ]; then
            v=$(cat "$1")
            echo -e "WR - A: $1 = $v\nWR - B: $1 = $2\n" >> $dpath
            [ $dryrun -eq 0 ] && echo -e "$2" > "$1" || echo "$1 write error.";
        fi
     fi
    }

    wrs(){
local v
    if [ "$dump" -eq 1 ]; then
        if [ -e "$1" ]; then
            v=$(cat "$1")
            echo -e "WRS - A: $1 = $v\nWRS - B: $1 = $2\n" >> $dpath
            [ $dryrun -eq 0 ] && echo -e "$2" > "$1" 2>&1
        fi
     fi
    }

    wrc(){
local v
    if [ "$dump" -eq 1 ]; then
        if [ -e "$1" ]; then
            v=$(cat "$1")
            if [ "$v" != "$2" ]; then
            echo -e "WRC - A: $1 = $v\nWRC - B: $1 = $2\n" >> $dpath
else echo -e "WRC - A: $1 = $v\nWRC - B: $1 = $2\n (no write)" >> $dpath; fi
            [ $dryrun -eq 0 ] && echo -e "$2" > "$1" 2>&1
        fi
     fi
    }

    wrl(){
local v
    if [ "$dump" -eq 1 ]; then
        if [ -e "$1" ]; then
            v=$(cat "$1")
            echo -e "WRL - A: $1 = $v\nWRL - B: $1 = $2\n" >> $dpath
             [ $dryrun -eq 0 ] && chmod 666 $1 && echo "$2" > "$1" && chmod 444 $1
        fi
    fi
    }

fi

# end dump

TIME() {
t=$(date +%s%3N)
"$@"
echo "$1: $((($(date +%s%3N)-t))) ms"
}

} # end vars

if [ $debug -eq "1" ]; then
vars && debug_run
else
vars && main_opt
fi

unset scriptname dump dryrun have np