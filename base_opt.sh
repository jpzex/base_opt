# base_opt.sh
# Version 1.1.1
# 2022-05-26 @ 00:20 (UTC)
# ID: RELEASE
# Written by @jpzex (XDA & Telegram)
# Use at your own risk, Busybox is required.

#set -xv # debug

##### USER SET VARIABLES #####

# Dump mode (0 or 1): log before and after for every value that is getting applied.
dump=0

# Dry run mode (0 or 1): do not change any value, just dump before and after if dump=1.
dryrun=0

##### DO NOT EDIT BELOW THIS LINE #####

prep(){

np=/dev/null

which busybox > $np

[ $? != 0 ] && echo "No busybox found, please install it first. If you just installed, a reboot may be necessary." && exit 1

alias_list="mountpoint awk echo grep chmod fstrim cat mount uniq"

for x in $alias_list; do
    alias $x="busybox $x";
done

scriptname=base_opt

}

# Generic optimizations.
# May not affect battery usage, just remove bottlenecks.

main_opt(){
M1 # ext4 and f2fs mountpoints
M2 # sysctl (generic)
M4 # I/O 
}

#===================================================#
#===================================================#
#===================================================#

# Module 1: Set mount flags to decrease overhead and improve writing performance

M1(){ 

if [ $dryrun == 0 ]; then
    for x in $(cat /proc/mounts | cut -d ' ' -f 1,2,3 | \
tr ' ' '&' | grep "/dev/" | grep -E 'ext4|f2fs'); do

        mpts=( $(echo $x | tr '&' ' ') )
        mountpoint -q ${mpts[1]} || continue

        case ${mpts[2]} in
            ext4 )
                flags=remount,noatime,nodiratime ;;
            f2fs )
                flags=remount,noatime,nodiratime,flush_merge ;;
            * ) 
                continue ;;
        esac

        mount -o remount,$flags ${mpts[0]}
        [ $(which fstrim) ] && fstrim ${mpts[1]} || \
        echo "${mpts[1]} fstrim error."
    done
fi

unset x mpts 

}

#===================================================#
#===================================================#
#===================================================#

# Module 2: Sysctl Tweaks

M2(){

sys=/proc/sys

fs_base(){
wr $sys/fs/aio-max-nr 131072 #65536 def
wr $sys/fs/file-max 131072 #65536 sug
wr $sys/fs/inode-max 524288 #262144 sug
wr $sys/fs/nr_open 2097152 #1048576 def
wr $sys/fs/inotify/max_queued_events 1048576 #16384 def
#wr $sys/fs/inotify/max_user_instances 1024 # 128 def
wr $sys/fs/inotify/max_user_watches 1048576 #8192 def
}

kernel_base(){
wr $sys/kernel/ctrl-alt-del 0
wr $sys/kernel/dmesg_restrict 1
wr $sys/kernel/panic 30 # 60 sug
wr $sys/kernel/panic_on_oops 1
wr $sys/kernel/perf_cpu_time_max_percent 0 #def 25
wr $sys/kernel/perf_event_mlock_kb 0 #def 516
wr $sys/kernel/printk "0 0 0 0"
}

net_base(){
wr $sys/net/core/netdev_max_backlog 16384 # sug
wr $sys/net/core/rmem_default 1048576 # sug
wr $sys/net/core/rmem_max 2097152 # manual
wr $sys/net/core/somaxconn 8192 #8192 sug
wr $sys/net/core/wmem_default 1048576 # mirr rmem
wr $sys/net/core/wmem_max 2097152 # mirr rmem
wr $sys/net/ipv4/ipfrag_high_thresh 8388608
wr $sys/net/ipv4/ipfrag_low_thresh 4194304
wr $sys/net/ipv4/ip_forward 1
wr $sys/net/ipv4/ip_no_pmtu_disc 1
wr $sys/net/ipv4/ipfrag_max_dist 128
wr $sys/net/ipv4/ipfrag_time 3
wr $sys/net/ipv4/min_pmtu 1460
wr $sys/net/ipv4/tcp_autocorking 0
wr $sys/net/ipv4/tcp_dsack 1
wr $sys/net/ipv4/tcp_early_retrans 2
wr $sys/net/ipv4/tcp_ecn 0
wr $sys/net/ipv4/tcp_fack 1
wr $sys/net/ipv4/tcp_fastopen 1
wr $sys/net/ipv4/tcp_fin_timeout 5 #nateware
wr $sys/net/ipv4/tcp_frto 1
wr $sys/net/ipv4/tcp_keepalive_time 1800 #900 sug
wr $sys/net/ipv4/tcp_keepalive_probes 2
wr $sys/net/ipv4/tcp_low_latency 0
wr $sys/net/ipv4/tcp_max_orphans 8192
wr $sys/net/ipv4/tcp_max_syn_backlog 8192 #nateware
wr $sys/net/ipv4/tcp_max_tw_buckets 65536 #nateware
wr $sys/net/ipv4/tcp_moderate_rcvbuf 1
wr $sys/net/ipv4/tcp_mtu_probing 1
wr $sys/net/ipv4/tcp_no_metrics_save 1
wr $sys/net/ipv4/tcp_reordering 3
wr $sys/net/ipv4/tcp_retries1 5
wr $sys/net/ipv4/tcp_retries2 10
wr $sys/net/ipv4/tcp_rfc1337 0
wr $sys/net/ipv4/tcp_sack 1 # sug 
wr $sys/net/ipv4/tcp_slow_start_after_idle 0 #nateware
wr $sys/net/ipv4/tcp_syn_retries 2
wr $sys/net/ipv4/tcp_synack_retries 2
wr $sys/net/ipv4/tcp_timestamps 1
wr $sys/net/ipv4/tcp_tw_recycle 0
wr $sys/net/ipv4/tcp_tw_reuse 1 #nateware
wr $sys/net/ipv4/tcp_window_scaling 1
wr $sys/net/ipv4/tcp_rmem "8192 1048576 2097152" #Cloudflare + nateware inspired
wr $sys/net/ipv4/tcp_wmem "8192 1048576 2097152" #mirr rmem
wr $sys/net/ipv4/udp_rmem_min 8192
wr $sys/net/ipv4/udp_wmem_min 8192
wr $sys/net/ipv4/route/flush 1
}

vm_base(){
wr $sys/vm/admin_reserve_kbytes 4096
wr $sys/vm/block_dump 0
wr $sys/vm/highmem_is_dirtyable 1
wr $sys/vm/min_free_kbytes $(($msize/200)) # 0.5% of total RAM 
wr $sys/vm/oom_kill_allocating_task 0
wr $sys/vm/oom_dump_tasks 0
wr $sys/vm/panic_on_oom 0
wr $sys/vm/page-cluster 12
wr $sys/vm/stat_interval 30
}

fs_base
kernel_base
net_base
vm_base

unset sys
}

#===================================================#
#===================================================#
#===================================================#

# Module 4: Block I/O tweaks

M4(){

iotweak(){
if [ -d /sys/block/$1/queue ]; then
     w="wrl /sys/block/$1/queue"
     if [ ! "$2" -gt "$(cat /sys/block/$1/queue/max_hw_sectors_kb)" ]; then
          $w/max_sectors_kb $2; fi  # 1
     $w/nr_request $3                     # 2
     $w/read_ahead_kb $4             # 3
     $w/nomerges $5                      # 4
     $w/rq_affinity $6                      # 5
     $w/iostats 0                              # decrease overhead
     $w/add_random 1                   # help create randomness
     $w/rotational 0                         # all flash storage
fi
}

# usually emmc
iotweak mmcblk0 512 1024 512 0 2

# usually sd card
iotweak mmcblk1 512 1024 512 0 2

# other dm partitions
for x in $(seq 0 5); do
    iotweak dm-$x 512 1024 512 0 2
done

# the more you know...

for x in /sys/block/*; do
    queue="$x/queue"
    w="wrl $queue/iosched"
    case $(read $queue/scheduler) in

        *cfq*)
            wrl $queue/scheduler cfq
            $w/slice_idle 0
            $w/back_seek_max 0
            $w/back_seek_penalty 0
            $w/fifo_expire_async 5000
            $w/fifo_expire_sync 500
            $w/low_latency 0
            $w/target_latency 0
            $w/group_idle 0
            $w/slice_async 200
            $w/slice_async_rq 32
            $w/quantum 32
            $w/slice_sync 1000
            break;;

         *deadline*)
            wrl $queue/scheduler deadline
            $w/fifo_batch 16
            $w/writes_starved 0
            $w/read_expire 1000
            $w/write_expire 10000
            $w/front_merges 0
             break;;

    esac
done

}

#===================================================#
#===================================================#
#===================================================#

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

prep && vars && main_opt
#if [ -z $dumpinfo ]; then echo $dumpinfo; fi

unset main_opt scriptname alias_list msize apply dump dryrun dpath wr wrl read search dumpinfo have np
