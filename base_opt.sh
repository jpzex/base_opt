# base_opt.sh
# Version 1.1.7
# 2025-07-10 @ 15:19 (UTC)
# ID: foa8qw
# Written by @jpzex (XDA & Telegram)
# With help of @InoCity (Telegram)
# Use at your own risk, Busybox is required.

#set -xv # debug

##### USER SET VARIABLES #####

# Dump mode (0 or 1): save a log of before and after for every value to be changed.
dump=0

# Dry run mode (0 or 1): do not apply any value, print on screen what it would change.
dryrun=0

##### DO NOT EDIT BELOW THIS LINE #####

scriptname=base_opt

# Generic optimizations.
# May not affect battery usage, just remove bottlenecks.

main_opt(){

M1 & # reduce mountpoint overhead
M2 & # sysctl fs, kernel, net and vm (generic)
M4 & # storage I/O optimization 

} # the others are present on batt_opt and game_opt

#===================================================#
#===================================================#
#===================================================#

# Module 1: Set mount flags to reduce overhead and improve I/O performance

M1(){ 

    if [ $dryrun -eq 0 ]; then
        for x in $(grep -E 'ext4|f2fs|erofs|susfs' /proc/mounts | awk '{split($2, a, "/"); print a[1] "/" a[2] "/" a[3] "&" $3}' | sed 's/\/$//' | sort -u); do
        local mpts=$(echo $x | tr '&' ' ')
        mountpoint -q ${mpts[0]} || continue

        case ${mpts[1]} in
            ext4 )
                flags=commit=10 ;;
            f2fs )
                flags=flush_merge,background_gc=on ;;
            erofs )
                flags=noacl,nouser_xattr,cache_strategy=readahead,dax=never ;;
            * ) 
                continue ;;
        esac

        mount -o remount,noatime,nodiratime,$flags ${mpts[0]}
        [ $(which fstrim) ] && fstrim ${mpts[0]} || \
        echo "${mpts[0]} fstrim error."

    done
fi

unset x mpts 

}

#===================================================#
#===================================================#
#===================================================#

# Module 2: Sysctl Tweaks for better memory management and improved networking bandwidth and stability

M2(){

local sys=/proc/sys

fs_base(){
wr  $sys/fs/aio-max-nr 262144 # 65536 def
wr  $sys/fs/inotify/max_user_instances 2048 # 1024 def
wr  $sys/fs/inotify/max_user_watches 65536 # 10240 def
}

kernel_base(){
wr  $sys/kernel/ctrl-alt-del 0
wr  $sys/kernel/dmesg_restrict 1
wr  $sys/kernel/panic 5 # 60 sug 5 def
wr  $sys/kernel/panic_on_oops 1
wr  $sys/kernel/perf_cpu_time_max_percent 1 #def 25
wr  $sys/kernel/perf_event_max_sample_rate 100 
wr  $sys/kernel/printk "0 0 0 0"
wr  $sys/kernel/sched_latency_ns 6000000
wr  $sys/kernel/sched_min_granularity_ns 1000000
wr  $sys/kernel/sched_rr_timeslice_ms 150 # 30 def
wr  $sys/kernel/sched_rt_period_us 1000000 # 1000000
wr  $sys/kernel/sched_rt_runtime_us "-1" # 950000 def
}

net_base(){
wr  $sys/net/core/netdev_max_backlog 512 # 64 OFLW 128 def
wr  $sys/net/core/rmem_default 262144
wr  $sys/net/core/rmem_max 1048576    
wr  $sys/net/core/somaxconn 256 # 128 def
wr  $sys/net/core/wmem_default 262144
wr  $sys/net/core/wmem_max 1048576
wr  $sys/net/ipv4/ip_forward 1 # runs earlier because it may reset ipv4 configs
wr  $sys/net/ipv4/ip_no_pmtu_disc 0
wr  $sys/net/ipv4/ipfrag_max_dist 128
wr  $sys/net/ipv4/ipfrag_time 3
wrl $sys/net/ipv4/min_pmtu 1400
wr  $sys/net/ipv4/tcp_abort_on_overflow 0
wr  $sys/net/ipv4/tcp_autocorking 1
wr  $sys/net/ipv4/tcp_dsack 1
wr  $sys/net/ipv4/tcp_early_retrans 2
wr  $sys/net/ipv4/tcp_ecn 0
wr  $sys/net/ipv4/tcp_fack 1
wr  $sys/net/ipv4/tcp_fastopen 3
wr  $sys/net/ipv4/tcp_fin_timeout 10 # 5 nateware, 10 keep TIME_WAIT for longer AI
wr  $sys/net/ipv4/tcp_frto 1
wr  $sys/net/ipv4/tcp_keepalive_time 600 #900 sug
wr  $sys/net/ipv4/tcp_keepalive_probes 2
wr  $sys/net/ipv4/tcp_low_latency 0
wr  $sys/net/ipv4/tcp_max_orphans 8192
wr  $sys/net/ipv4/tcp_max_syn_backlog 256
wr  $sys/net/ipv4/tcp_max_tw_buckets 4096
wr  $sys/net/ipv4/tcp_mem "131072 262144 524288" 
wr  $sys/net/ipv4/tcp_moderate_rcvbuf 1
wr  $sys/net/ipv4/tcp_mtu_probing 2 # always probe mtu
wr  $sys/net/ipv4/tcp_no_metrics_save 0
wr  $sys/net/ipv4/tcp_reordering 5
wr  $sys/net/ipv4/tcp_retries1 3
wr  $sys/net/ipv4/tcp_retries2 8
wr  $sys/net/ipv4/tcp_rfc1337 0
wr  $sys/net/ipv4/tcp_sack 1
wr  $sys/net/ipv4/tcp_slow_start_after_idle 1 #nateware
wr  $sys/net/ipv4/tcp_syn_retries 2
wr  $sys/net/ipv4/tcp_synack_retries 2
wr  $sys/net/ipv4/tcp_timestamps 1
wrl $sys/net/ipv4/tcp_tw_recycle 0
wr  $sys/net/ipv4/tcp_tw_reuse 1
wr  $sys/net/ipv4/tcp_window_scaling 1
wr  $sys/net/ipv4/tcp_rmem "8192 131072 1048576"
wr  $sys/net/ipv4/tcp_wmem "8192 131072 1048576"
wr  $sys/net/ipv4/udp_rmem_min 16384
wr  $sys/net/ipv4/udp_wmem_min 16384
}

vm_base(){
wr  $sys/vm/admin_reserve_kbytes 6144 # 8192 def, slight decrease for more free RAM
wr  $sys/vm/block_dump 0 # decrease logging
wr  $sys/vm/extfrag_threshold 1000 # 500 def, increased to allow more ram fragmentation and reduce CPU usage
wr  $sys/vm/extra_free_kbytes 6144
wr  $sys/vm/min_free_kbytes 6144
wr  $sys/vm/laptop_mode 0 # we run flash storage
wr  $sys/vm/oom_kill_allocating_task 0 # let LMK do the job
wr  $sys/vm/oom_dump_tasks 0 # decrease logging
wr  $sys/vm/panic_on_oom 0 # the kernel can handle OOMs
wr  $sys/vm/stat_interval 5 # less frequent updates
wr  $sys/vm/user_reserve_kbytes 6144 # def 3% mem
}

fs_base &
kernel_base &
net_base &
vm_base &

unset sys fs_base kernel_base net_base vm_base
}

#===================================================#
#===================================================#
#===================================================#

# Module 4: Block I/O tweaks to decrease overhead and improve transfer bandwidth and latency

M4(){

iotweak(){
q=$1/queue
if [ -d $q ]; then
    local w="wrl $q/iosched"
    
    case "$(readf $q/scheduler)" in

    *"[none]"*)
        :
    ;;
    
    *bfq*)
        wrl $q/scheduler bfq
        $w/back_seek_max 0
        $w/low_latency 0
        $w/slice_idle 0
        $w/quantum 8
        $w/strict_guarantees 0
    ;;
    
    *mq-deadline*)
        wrl $q/scheduler mq-deadline
        $w/fifo_batch 32
        $w/front_merges 1
        $w/read_expire 500
        $w/write_expire 5000
        $w/writes_starved 16
    ;;
    
    *cfq*)
        wrl $q/scheduler cfq
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
        wrl $q/scheduler deadline
        $w/fifo_batch 32
        $w/front_merges 1
        $w/read_expire 500
        $w/write_expire 5000
        $w/writes_starved 16
    ;;

    esac

    unset w
    
    local w="wrl $q"
    if [ ! "$2" -gt "$(cat $q/max_hw_sectors_kb)" ]; then
    $w/max_sectors_kb $2; fi       # 128 default
    $w/nr_requests $3              # 128 default
    $w/read_ahead_kb $4            # 128 default
    $w/nomerges $5                 # 0 merge, 1 simple only, 2 nomerge
    $w/rq_affinity $6              # 1 group, 2 core
    $w/iostats 0                   # decrease overhead
    $w/add_random 0                # help create randomness
    $w/rotational 0                # 0 flash, 1 hdd
    
fi
}

hasdm=0
# encrypted and/or logical partitions
for x in /sys/block/dm*; do
    hasdm=1
    iotweak $x 1024 64 256 2 2 &
done
if [ $hasdm == 0 ]; then
    # exposed physical device (no dm-X)
    iotweak /sys/block/mmcblk0 1024 64 256 2 2 &
    else
    # underlying physical device (with dm-X)
    for x in /sys/block/mmcblk0 /sys/block/sd*; do
        iotweak $x 1024 64 256 2 2 &
    done
fi

# exposed physical external sd card
iotweak /sys/block/mmcblk1 256 256 256 2 2 &

unset q w x hasdm iotweak
}

#===================================================#
#===================================================#
#===================================================#

prep(){

np=/dev/null

which busybox > $np

[ $? != 0 ] && echo "No busybox found, please install it first. If you just installed, a reboot may be necessary." && exit 1

alias_list="mountpoint awk echo grep chmod fstrim cat mount uniq date"

for x in $alias_list; do
    alias $x="busybox $x";
done

marker="/data/lastrun_$scriptname"

if [ $dryrun -eq 0 ]; then touch $marker; echo $(date) > $marker; fi
unset marker

} # end prep

vars(){

readf(){ [ -e $1 ] && cat $1; }

search(){ readf $2 | grep $1 > $np; }

# search <string> <file>
# searches for string in file if it exists and returns
# just an error code, 0 (true) for "string found" or 
# 1 (false) for "not found". Does not print.

#=DUMP=AND=DRY=RUN=START============================#

if [ $dryrun -eq 0 ]; then
    have="have"

wr(){
    [ -e "$1" ] && echo -e "$2" > "$1" || \
    echo "ERROR: Cannot write $2 to $1."
}

wrl(){
    [ -e $1 ] && chmod 666 $1 && \
    echo -e "$2" > "$1" && chmod 444 $1
}

else
    have="have not"
    wr(){ [ -e $1 ] && echo -e "WR : $2 > $1"; }
    wrl(){ [ -e $1 ] && echo -e "WRL: $2 > $1"; }
fi

if [ $dump -eq 1 ]; then
    dpath=/data/$scriptname
    for x in $dpath*; do
        [ -e $x ] && rm $x
    done
    dpath="$dpath-$(date +%Y-%m-%d).txt"
    echo "The dump file is located in: $dpath. The values $have been applied because dryrun=$dryrun."

    wr(){
    if [ $dump -eq 1 ]; then
        if [ -e $1 ]; then
            echo -e "WR - A: $1 = $(cat $1)\nWR - B: $1 = $2\n" >> $dpath
            [ $dryrun -eq 0 ] && echo -e "$2" > "$1" || echo "$1 write error.";
        fi
     fi
    }

    wrl(){
    if [ $dump -eq 1 ]; then
        if [ -e $1 ]; then
            echo -e "WRL - A: $1 = $(cat $1)\nWRL - B: $1 = $2\n" >> $dpath
             [ $dryrun -eq 0 ] && chmod 666 $1 && echo $2 > $1 && chmod 444 $1
        fi
    fi
    }

fi # end dump

#=DUMP=AND=DRY=RUN=END==============================#

} # end vars

prep && vars && main_opt

unset main_opt scriptname alias_list dump dryrun dpath wr wrl readf search have np
