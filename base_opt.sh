# base_opt.sh
# Version 1.1
# 2022-05-27 @ 21:36 (UTC)
# ID: RELEASE
# Written by jpzex (XDA & Telegram)
# Use at your own risk, Busybox is required.

##### USER SET VARIABLES #####

# Dump mode (0 or 1): log before and after for every value that would be applied.
dump=0

# Dry run mode (0 or 1): do not change any value, just dump before and after if dump=1.
dryrun=0

##### DO NOT EDIT BELOW THIS LINE #####

which busybox > /dev/null

if [ ! $? == 0 ]; then
    echo "No busybox found.";
    exit 0;
fi

alias_list="mountpoint awk echo grep chmod fstrim cat mount"

for x in $alias_list; do
    alias $x="busybox $x";
done

scriptname=base_opt

# Generic optimizations.
# May not affect battery usage, just remove bottlenecks.

generic_opt(){
M1 # ext4 and f2fs mountpoints
M2 # sysctl (generic)
M4 # I/O
}

#===================================================#
#===================================================#
#===================================================#

# Module 1: Adjust mount flags based on FS

M1(){ 

read /proc/mounts | grep " / ext4" > /dev/null && root=/

list="/system /data /cache /data/sdext2 $root"

for x in $list; do
    [ -e $x ] && [ ! -L $x ] && mountpoint -q $x &&\
    search " $x " /proc/mounts && list2="$x $list2"
    devlist="$(grep /dev/block /proc/mounts | \
    grep "$x " | awk '{ print $1 }') $devlist";
done

for x in $list; do
    case $(grep " $x " /proc/mounts | awk '{ print $3 }') in
        "ext4")
            flags="discard barrier noatime nodiratime";;
        "f2fs")
            flags="active_logs=4 noatime nodiratime \
            noacl nobarrier background_gc=on";;
         *)
            break;; 
    esac
    if [ $dryrun == 0 ]; then
        for y in $flags; do
            mount -o remount,$y $x
        done
    fi
done

# fstrim all existing f2fs and ext4 partitions.

[ $(which fstrim) ] && [ $dryrun == 0 ] &&\
for x in $list2; do
    [ -e $x ] && mountpoint -q $x && fstrim $x
done

unset list list2 devlist flags x root

}

#===================================================#
#===================================================#
#===================================================#

# Module 2: Sysctl Tweaks

M2(){

sys=/proc/sys

# fs_base
wr $sys/fs/file-max 131072
wr $sys/fs/inotify/max_queued_events 1048576
#wr $sys/fs/inotify/max_user_instances 1024 # not mess
wr $sys/fs/inotify/max_user_watches 1048576

# kernel_base
wr $sys/kernel/ctrl-alt-del 0
wr $sys/kernel/panic 10
wr $sys/kernel/panic_on_oops 1
wr $sys/kernel/printk "0 0 0 0"

# net_base
wr $sys/net/core/netdev_max_backlog 512
wr $sys/net/core/rmem_default 524288
wr $sys/net/core/rmem_max 4194304
wr $sys/net/core/somaxconn 512
wr $sys/net/core/wmem_default 524288
wr $sys/net/core/wmem_max 4194304
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
wr $sys/net/ipv4/tcp_fin_timeout 10
wr $sys/net/ipv4/tcp_frto 1
wr $sys/net/ipv4/tcp_keepalive_time 3600
wr $sys/net/ipv4/tcp_keepalive_probes 5
wr $sys/net/ipv4/tcp_low_latency 0
wr $sys/net/ipv4/tcp_max_orphans 8192
wr $sys/net/ipv4/tcp_max_syn_backlog 256 #fix
wr $sys/net/ipv4/tcp_max_tw_buckets 8192
wr $sys/net/ipv4/tcp_mem "8192 16384 20480"
wr $sys/net/ipv4/tcp_moderate_rcvbuf 1
wr $sys/net/ipv4/tcp_mtu_probing 1
wr $sys/net/ipv4/tcp_no_metrics_save 1
wr $sys/net/ipv4/tcp_reordering 3
wr $sys/net/ipv4/tcp_retries1 5
wr $sys/net/ipv4/tcp_retries2 10
wr $sys/net/ipv4/tcp_rfc1337 0
wr $sys/net/ipv4/tcp_sack 1
wr $sys/net/ipv4/tcp_synack_retries 3
wr $sys/net/ipv4/tcp_timestamps 0
wr $sys/net/ipv4/tcp_tw_recycle 0
wr $sys/net/ipv4/tcp_tw_reuse 0
wr $sys/net/ipv4/tcp_window_scaling 1
wr $sys/net/ipv4/tcp_rmem "65536 131072 1048576"
wr $sys/net/ipv4/tcp_wmem "65536 131072 1048576"
wr $sys/net/ipv4/udp_mem "65536 131072 1048576"
wr $sys/net/ipv4/udp_wmem_min 65536
wr $sys/net/ipv4/route/flush 1

# vm_base
wr $sys/vm/highmem_is_dirtyable 0
wr $sys/vm/min_free_kbytes 8192
wr $sys/vm/oom_kill_allocating_task 1
wr $sys/vm/oom_dump_tasks 0
wr $sys/vm/panic_on_oom 0
wr $sys/vm/page-cluster 1
wr $sys/vm/stat_interval 60

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
          $w/max_sectors_kb $2
     fi
     $w/nr_request $3
     $w/read_ahead_kb $4
     $w/nomerges $5
     $w/rq_affinity $6
     $w/iostats $7
     $w/add_random $8
     $w/rotational $9
fi
}

iotweak mmcblk0 512 512 32 2 2 0 0 0
iotweak mmcblk1 128 32   32 2 0 0 0 0
iotweak dm-0        512 512 32 2 2 0 0 0
iotweak dm-1        512 512 32 2 2 0 0 0 

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
            $w/slice_sync 1000;;
        *deadline*)
            wrl $queue/scheduler deadline
            $w/fifo_batch 16
            $w/writes_starved 0
            $w/read_expire 100
            $w/write_expire 10000
            $w/front_merges 1;;
        *)
            search noop $queue/scheduler &&\
            wrl $queue/scheduler noop
    esac
done

}

#===================================================#
#===================================================#
#===================================================#

# Get RAM size in KB 
msize=$(cat /proc/meminfo | grep "MemTotal" | awk '{ print $2 }')

read(){ [ -e $1 ] && cat $1; }

search(){ read $2 | grep $1 >> /dev/null; }

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
    dumpinfo="The dump file is located in: $dpath. The values $have been applied, according to the config on the start of the script."

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

generic_opt

echo $dumpinfo

unset generic_opt msize apply dump dryrun dpath wr wrl read search dumpinfo have

exit 0
