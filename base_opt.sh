# base_opt.sh
# Version 1.0.1
# 2021-06-22 @ 23:30 (UTC)
# ID: 2wnukx
# Written by jpzex@XDA
# Use at your own risk, Busybox is required.

which busybox > /dev/null || $(echo "No busybox found." && exit 0)

alias_list="
mountpoint
awk
echo
grep
chmod
fstrim
cat
mount"

for x in $alias_list; do
alias $x="busybox $x"; done

scriptname=base_opt
dumpE=0

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

for x in $list; do [ -e $x ] && [ ! -L $x ] && mountpoint -q $x && search " $x " /proc/mounts && list2="$x
$list2"
devlist="$(grep /dev/block /proc/mounts | grep "$x " | awk '{ print $1 }')
$devlist"; done

for x in $list2; do

case $(grep " $x " /proc/mounts | awk '{ print $3 }') in

"ext4")
flags="
discard
barrier
noatime
nodiratime
";;

# noblock_validity,inode_readahead_blks=16
# auto_da_alloc,commit=10,delalloc
# max_batch_time=100000

"f2fs")
flags="
active_logs=4
noatime
nodiratime
barrier
";;

# noacl,flush_merge,disable_ext_identify
# nouser_xattr,no_heap,nodiscard - error when apply

*)
break;; 

esac

if [ $dumpE == 0 ]; then
for y in $flags; do mount -o remount,$y $x; done; fi

done

# fstrim all f2fs and ext4 partitions found.

[ $(which fstrim) ] && [ $dumpE == 0 ] && for x in $list2; do [ -e $x ] && mountpoint -q $x && fstrim $x; done

unset list list2 devlist flags x root

}

#===================================================#
#===================================================#
#===================================================#

# Module 2: Sysctl Tweaks

M2(){

sys=/proc/sys

fs_generic(){
wr $sys/fs/file-max 131072
wr $sys/fs/inotify/max_queued_events 1048576
#wr $sys/fs/inotify/max_user_instances 1024 # not mess
wr $sys/fs/inotify/max_user_watches 1048576
}

kernel_generic(){
wr $sys/kernel/ctrl-alt-del 0
wr $sys/kernel/panic 10
wr $sys/kernel/panic_on_oops 1
wr $sys/kernel/printk "0 0 0 0"
}

net_generic(){
wr $sys/net/core/netdev_max_backlog 256
wr $sys/net/core/rmem_default 262144
wr $sys/net/core/rmem_max 262144
wr $sys/net/core/somaxconn 512
wr $sys/net/core/wmem_default 262144
wr $sys/net/core/wmem_max 262144
wr $sys/net/ipv4/ipfrag_high_thresh 8388608
wr $sys/net/ipv4/ipfrag_low_thresh 4194304
wr $sys/net/ipv4/ip_forward 1
wr $sys/net/ipv4/ip_no_pmtu_disc 0
wr $sys/net/ipv4/ipfrag_max_dist 128
wr $sys/net/ipv4/ipfrag_time 5
wr $sys/net/ipv4/tcp_autocorking 1
wr $sys/net/ipv4/tcp_dsack 1
wr $sys/net/ipv4/tcp_ecn 1
wr $sys/net/ipv4/tcp_fack 1
wr $sys/net/ipv4/tcp_fastopen 0
wr $sys/net/ipv4/tcp_fin_timeout 20
wr $sys/net/ipv4/tcp_frto 1
wr $sys/net/ipv4/tcp_low_latency 0
wr $sys/net/ipv4/tcp_max_orphans 128
wr $sys/net/ipv4/tcp_max_syn_backlog 256 #fix
wr $sys/net/ipv4/tcp_max_tw_buckets 128
wr $sys/net/ipv4/tcp_mem "4096 4096 4096"
wr $sys/net/ipv4/tcp_moderate_rcvbuf 1
wr $sys/net/ipv4/tcp_mtu_probing 2
wr $sys/net/ipv4/tcp_no_metrics_save 0 #fix
wr $sys/net/ipv4/tcp_reordering 5
wr $sys/net/ipv4/tcp_rfc1337 1
wr $sys/net/ipv4/tcp_sack 0
wr $sys/net/ipv4/tcp_synack_retries 5
wr $sys/net/ipv4/tcp_timestamps 0
wr $sys/net/ipv4/tcp_tw_recycle 0
wr $sys/net/ipv4/tcp_tw_reuse 0
wr $sys/net/ipv4/tcp_window_scaling 0
wr $sys/net/ipv4/tcp_rmem "8192 131072 1048576"
wr $sys/net/ipv4/tcp_wmem "8192 131072 1048576"
wr $sys/net/ipv4/udp_mem "8182 131072 1048576"
wr $sys/net/ipv4/udp_wmem_min 65536
wr $sys/net/ipv4/route/flush 1
}

vm_generic(){
wr $sys/vm/highmem_is_dirtyable 1
wr $sys/vm/min_free_kbytes 1024
wr $sys/vm/oom_kill_allocating_task 1
wr $sys/vm/oom_dump_tasks 0
wr $sys/vm/panic_on_oom 0
wr $sys/vm/page-cluster 1
wr $sys/vm/stat_interval 60
}

sysctl_apply(){
fs_generic
kernel_generic
net_generic
vm_generic
}

sysctl_apply

unset sys fs kernel vm_generic net sysctl_apply
}

#===================================================#
#===================================================#
#===================================================#

# Module 4: Block I/O tweaks

M4(){

iotweak(){

w="wrl /sys/block/$1/queue"

$w/max_sectors_kb $2
$w/iostats $3 
$w/add_random $4 
$w/read_ahead_kb $5
$w/nomerges $6
$w/rotational $7
$w/rq_affinity $8

}

iotweak mmcblk0 256 0 0 0 0 0 1
iotweak mmcblk1 256 0 0 0 0 0 1
iotweak dm-0 127 0 0 0 0 0 1

for x in /sys/block/*; do

w="wrl $x/queue/iosched"

case $(read $queue/scheduler) in

*cfqd*)

wrl $x/scheduler cfq

# cfq specific tuning

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

wrl $x/scheduler deadline

# deadline specific tuning

$w/fifo_batch 64
$w/writes_starved 8
$w/read_expire 100
$w/write_expire 2000
$w/front_merges 0;;

*)

search noop $queue/scheduler && wrl $queue/scheduler noop

esac; done

}

#===================================================#
#===================================================#
#===================================================#

read(){ [ -e $1 ] && cat $1; }

search(){ read $2 | grep $1 >> /dev/null; }

# search <string> <file>
# searches for string in file if it exists and returns
# just an error code, 0 (true) for "string found" or 
# 1 (false) for "not found". Does not print.

wr(){
[ -e $1 ] && $(echo -e $2 > $1 || echo "$1 write error."); }

wrl(){
[ -e $1 ] && chmod 666 $1 && echo $2 > $1 && chmod 444 $1; }

if [ $dumpE == 1 ]; then # initialize dump

dpath=/data/$scriptname

for x in $dpath*; do
[ -e $x ] && rm $x; done

dump="$dpath-$(date +%Y-%m-%d).txt"

wr(){
if [ -e $1 ]; then
echo -e "WR - A: $1 = $(cat $1)\nWR - B: $1 = $2\n" >> $dump; fi; }

wrl(){
if [ -e $1 ]; then
echo -e "WRL - A: $1 = $(cat $1)\nWRL - B: $1 = $2\n" >> $dump;
chmod 666 "$1"; fi; }

fi # end dump

marker="/data/$scriptname-last-run"

if [ $dumpE == 0 ]; then touch $marker; echo $(date) > $marker; fi
unset marker

# Get highest CPU core number
kernel_max=$(cat /sys/devices/system/cpu/kernel_max)

# Get RAM size in KB 
msize=$(cat /proc/meminfo | grep "MemTotal" | awk '{ print $2 }')

generic_opt

unset generic_opt dumpE msize kernel_max apply dump dpath marker

exit 0
