# base_opt.sh
# Version 1.1.4
# 2024-11-07 @ 22:31 (UTC)
# ID: gpekd8
# Written by @jpzex (XDA & Telegram)
# Use at your own risk, Busybox is required.

#set -xv # debug

##### USER SET VARIABLES #####

# Dump mode (0 or 1): log before and after for every value that is getting applied.
dump=0

# Dry run mode (0 or 1): do not change any value, just dump before and after if dump=1.
dryrun=0

##### DO NOT EDIT BELOW THIS LINE #####

scriptname=base_opt

# Generic optimizations.
# May not affect battery usage, just remove bottlenecks.

main_opt(){

M1 # ext4 and f2fs mountpoints
M2 # sysctl (generic)
M4 # I/O 

} # other modules are present on batt_opt and game_opt

#===================================================#
#===================================================#
#===================================================#

# Module 1: Set mount flags to decrease overhead and improve I/O performance

M1(){ 

    if [ $dryrun == 0 ]; then
        for x in $(grep -E 'ext4|f2fs' /proc/mounts | awk '{split($2, a, "/"); print a[1] "/" a[2] "/" a[3] "&" $3}' | sed 's/\/$//' | sort -u); do
        mpts=$(echo $x | tr '&' ' ')
        mountpoint -q ${mpts[0]} || continue

        case ${mpts[1]} in
            ext4 )
                flags=remount,noatime,nodiratime ;;
            f2fs )
                flags=remount,noatime,nodiratime,flush_merge ;;
            * ) 
                continue ;;
        esac

        mount -o remount,$flags ${mpts[0]}
        [ $(which fstrim) ] && fstrim ${mpts[0]} || \
        echo "${mpts[0]} fstrim error."

    done
fi

unset x mpts 

}

#===================================================#
#===================================================#
#===================================================#

# Module 2: Sysctl Tweaks for better memory management

M2(){

sys=/proc/sys

fs_base(){
wr $sys/fs/aio-max-nr 1048576 # 65536 def
wr $sys/fs/inotify/max_user_instances 8192 # 1024 def
wr $sys/fs/inotify/max_user_watches 524288 # 10240 def
}

kernel_base(){
wr $sys/kernel/ctrl-alt-del 0
wr $sys/kernel/dmesg_restrict 1
wr $sys/kernel/panic 3 # 60 sug 5 def
wr $sys/kernel/panic_on_oops 1
wr $sys/kernel/perf_cpu_time_max_percent 1 #def 25
wr $sys/kernel/printk "0 0 0 0"
wr $sys/kernel/sched_child_runs_first 0
#wr $sys/kernel/sched_rr_timeslice_ms 50 # 30 def
#wr $sys/kernel/sched_rt_period_us 2000000 # 1000000
#wr $sys/kernel/sched_rt_runtime_us "-1" # 950000 def
}

net_base(){
wr $sys/net/core/netdev_max_backlog 2048 # enough
wr $sys/net/core/rmem_default 65536
wr $sys/net/core/rmem_max 131072
wr $sys/net/core/somaxconn 512
wr $sys/net/core/wmem_default 65536
wr $sys/net/core/wmem_max 131072
wr $sys/net/ipv4/ip_forward 1 # resets all config
wr $sys/net/ipv4/ipfrag_high_thresh 8388608
wr $sys/net/ipv4/ipfrag_low_thresh 4194304
wr $sys/net/ipv4/ip_no_pmtu_disc 1
wr $sys/net/ipv4/ipfrag_max_dist 128
wr $sys/net/ipv4/ipfrag_time 3
wr $sys/net/ipv4/min_pmtu 1460
wr $sys/net/ipv4/tcp_abort_on_overflow 1
wr $sys/net/ipv4/tcp_autocorking 0
wr $sys/net/ipv4/tcp_dsack 1
wr $sys/net/ipv4/tcp_early_retrans 2
wr $sys/net/ipv4/tcp_ecn 0
wr $sys/net/ipv4/tcp_fack 1
wr $sys/net/ipv4/tcp_fastopen 1
wr $sys/net/ipv4/tcp_fin_timeout 5 #nateware
wr $sys/net/ipv4/tcp_frto 1
wr $sys/net/ipv4/tcp_keepalive_time 300 #900 sug
wr $sys/net/ipv4/tcp_keepalive_probes 2
wr $sys/net/ipv4/tcp_low_latency 0
wr $sys/net/ipv4/tcp_max_orphans 8192
wr $sys/net/ipv4/tcp_max_syn_backlog 256
wr $sys/net/ipv4/tcp_max_tw_buckets 65536 #nateware
wr $sys/net/ipv4/tcp_mem "8192 16384 32768" 
wr $sys/net/ipv4/tcp_moderate_rcvbuf 1
wr $sys/net/ipv4/tcp_mtu_probing 1
wr $sys/net/ipv4/tcp_no_metrics_save 0
wr $sys/net/ipv4/tcp_reordering 3
wr $sys/net/ipv4/tcp_retries1 2
wr $sys/net/ipv4/tcp_retries2 5
wr $sys/net/ipv4/tcp_rfc1337 0
wr $sys/net/ipv4/tcp_sack 0 # sug 
wr $sys/net/ipv4/tcp_slow_start_after_idle 1 #nateware
wr $sys/net/ipv4/tcp_syn_retries 2
wr $sys/net/ipv4/tcp_synack_retries 2
wr $sys/net/ipv4/tcp_timestamps 1
wr $sys/net/ipv4/tcp_tw_recycle 0
wr $sys/net/ipv4/tcp_tw_reuse 1
wr $sys/net/ipv4/tcp_window_scaling 1
wr $sys/net/ipv4/tcp_rmem "65536 131072 524288"
wr $sys/net/ipv4/tcp_wmem "65536 131072 524288"
wr $sys/net/ipv4/udp_rmem_min 8192
wr $sys/net/ipv4/udp_wmem_min 8192
}

vm_base(){
wr $sys/vm/admin_reserve_kbytes 4096 # 8192 def
wr $sys/vm/block_dump 0
wr $sys/vm/extfrag_threshold 1000 # 500 def
wr $sys/vm/extra_free_kbytes 16384 # 65536 last
wr $sys/vm/highmem_is_dirtyable 1
wr $sys/vm/min_free_kbytes 8192
wr $sys/vm/mmap_min_addr 65536
wr $sys/vm/laptop_mode 0
wr $sys/vm/lowmem_reserve_ratio "64 64" # 32 32 def
wr $sys/vm/oom_kill_allocating_task 0
wr $sys/vm/oom_dump_tasks 0
wr $sys/vm/panic_on_oom 0
wr $sys/vm/stat_interval 5
wr $sys/vm/user_reserve_kbytes 2048 # def 3% mem
}

fs_base
kernel_base
net_base
vm_base

unset sys fs_base kernel_base net_base vm_base
}

#===================================================#
#===================================================#
#===================================================#

# Module 4: Block I/O tweaks to decrease overhead and improve access latency

M4(){

iotweak(){
if [ -d /sys/block/$1/queue ]; then
     w="wrl /sys/block/$1/queue"
	 if [ ! "$2" -gt "$(cat /sys/block/$1/queue/max_hw_sectors_kb)" ]; then
          $w/max_sectors_kb $2; fi  # 1
     $w/nr_request $3               # 2
     $w/read_ahead_kb $4            # 3
     $w/nomerges $5                 # 4
     $w/rq_affinity $6              # 5
     $w/iostats 0                   # decrease overhead
     $w/add_random 0                # help create randomness
     $w/rotational 0                # all flash storage
fi
}

# usually internal emmc
iotweak mmcblk0 1024 1024 32 2 0

# usually external sd card
iotweak mmcblk1 1024 1024 32 2 0

# usually encrypted data or system partitions
for x in $(seq 0 5); do
    iotweak dm-$x 1024 1 32 2 0
done

# the more you know...

for x in /sys/block/*; do
    queue="$x/queue"
    w="wrl $queue/iosched"
    case $(read $queue/scheduler) in

        *cfq*)
            wrl $queue/scheduler cfq
            $w/slice_idle 0
            $w/back_seek_max 1048576
            $w/back_seek_penalty 1
            $w/fifo_expire_async 1000
            $w/fifo_expire_sync 100
            $w/low_latency 0
            $w/target_latency 0
            $w/group_idle 0
            $w/slice_async 1000
            $w/slice_async_rq 1
            $w/slice_sync 100
            $w/quantum 16
            break;;

         *deadline*)
            wrl $queue/scheduler deadline
            $w/fifo_batch 32
            $w/writes_starved 16
            $w/read_expire 500
            $w/write_expire 5000
            $w/front_merges 1
             break;;

    esac
done

unset queue w x
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

} # end prep

vars(){

# Get RAM size in KB 
msize=$(cat /proc/meminfo | grep "MemTotal" | awk '{ print $2 }')

read(){ [ -e $1 ] && cat $1; }

search(){ read $2 | grep $1 > $np ; }

# search <string> <file>
# searches for string in file if it exists and returns
# just an error code, 0 (true) for "string found" or 
# 1 (false) for "not found". Does not print.

#=DUMP=AND=DRY=RUN=START============================#

if [ $dryrun == 0 ]; then
have="have"

wr(){
[ -e $1 ] && $(echo -e $2 > $1 ||\
echo "$1 write error.")
}

wrl(){
[ -e $1 ] && chmod 666 $1 &&\
echo $2 > $1 && chmod 444 $1
}

else
have="have not"
wr(){
[ -e $1 ] && echo -e "$2 > $1" 
}

wrl(){
wr $1 $2
}

fi

if [ $dump == 1 ]; then
    dpath=/data/$scriptname
    for x in $dpath*; do
        [ -e $x ] && rm $x
    done
    dpath="$dpath-$(date +%Y-%m-%d).txt"
    echo "The dump file is located in: $dpath. The values $have been applied, according to the config on the start of the script."

    wr(){
    if [ $dump == 1 ]; then
        if [ -e $1 ]; then
            echo -e "WR - A: $1 = $(cat $1)\nWR - B: $1 = $2\n" >> $dpath
            [ $dryrun == 0 ] && $(echo -e $2 > $1 || echo "$1 write error.");
        fi
     fi
}

    wrl(){
    if [ $dump == 1 ]; then
        if [ -e $1 ]; then
            echo -e "WRL - A: $1 = $(cat $1)\nWRL - B: $1 = $2\n" >> $dpath
             [ $dryrun == 0 ] && chmod 666 $1 && echo $2 > $1 && chmod 444 $1
        fi
    fi
}

fi # end dump

#=DUMP=AND=DRY=RUN=END==============================#

} # end vars

marker="/data/lastrun_$scriptname"

if [ $dryrun == 0 ]; then touch $marker; echo $(date) > $marker; fi
unset marker

prep && vars && main_opt
#if [ -z $dumpinfo ]; then echo $dumpinfo; fi

unset main_opt scriptname alias_list msize apply dump dryrun dpath wr wrl read search dumpinfo have np
