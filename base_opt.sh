# base_opt.sh
# Version 1.0
# 2021-04-15 @ 03:32 (UTC)
# ID: 16reme
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
# Does not affect performance or battery.

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

# errors happened on Android 11 for this list below
#list="/system /data /oem /cache /vendor /lta-label /efs /firmware /product /persist /sd-ext /data/sdext2"

read /proc/mounts | grep " / ext4" > /dev/null && root=/

#that's why I made it simpler
list="/system /data /cache $root"

for x in $list; do [ -e $x ] && [ ! -L $x ] && mountpoint -q $x && search " $x " /proc/mounts && list2="$x
$list2"
devlist="$(grep /dev/block /proc/mounts | grep "$x " | awk '{ print $1 }')
$devlist"; done

for x in $list2; do

case $(grep " $x " /proc/mounts | awk '{ print $3 }') in

"ext4")
flags="
commit=30
nodiscard
nobarrier
noatime
nodiratime";;

# noblock_validity,inode_readahead_blks=16
# delalloc,auto_da_alloc

"f2fs")
flags="
active_logs=4
noatime
nodiratime
nobarrier";;

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
#wr $sys/fs/inotify/max_queued_events 16384 # better
#wr $sys/fs/inotify/max_user_instances 1024 # not mess
#wr $sys/fs/inotify/max_user_watches 16384 # with this
}

kernel_generic(){
wr $sys/kernel/ctrl-alt-del 0
wr $sys/kernel/panic 10
wr $sys/kernel/panic_on_oops 1
wr $sys/kernel/printk "0 0 0 0"
}

net_generic(){
wr $sys/net/core/netdev_max_backlog 8192
wr $sys/net/core/rmem_default 131072
wr $sys/net/core/rmem_max 524288
wr $sys/net/core/somaxconn 4096
wr $sys/net/core/wmem_default 131072
wr $sys/net/core/wmem_max 524288
wr $sys/net/ipv4/ip_forward 0
wr $sys/net/ipv4/tcp_autocorking 1
wr $sys/net/ipv4/ipfrag_time 10
wr $sys/net/ipv4/tcp_dsack 0
wr $sys/net/ipv4/tcp_ecn 2
wr $sys/net/ipv4/tcp_fack 0
wr $sys/net/ipv4/tcp_fastopen 3
wr $sys/net/ipv4/tcp_fin_timeout 30
wr $sys/net/ipv4/tcp_low_latency 0
wr $sys/net/ipv4/tcp_max_orphans 512
wr $sys/net/ipv4/tcp_max_syn_backlog 2048
wr $sys/net/ipv4/tcp_max_tw_buckets 1024
wr $sys/net/ipv4/tcp_moderate_rcvbuf 1
wr $sys/net/ipv4/tcp_mtu_probing 2
wr $sys/net/ipv4/tcp_no_metrics_save 0
wr $sys/net/ipv4/tcp_reordering 3
wr $sys/net/ipv4/tcp_rfc1337 0
wr $sys/net/ipv4/tcp_sack 0
wr $sys/net/ipv4/tcp_synack_retries 8
wr $sys/net/ipv4/tcp_timestamps 0
wr $sys/net/ipv4/tcp_tw_recycle 1
wr $sys/net/ipv4/tcp_tw_reuse 1
wr $sys/net/ipv4/tcp_window_scaling 1
wr $sys/net/ipv4/tcp_rmem "131072 262144 524288"
wr $sys/net/ipv4/tcp_wmem "131072 262144 524288"
wr $sys/net/ipv4/udp_mem "131072 262144 524288"
wr $sys/net/ipv4/udp_wmem_min 65536
wr $sys/net/ipv4/route/flush 1
}

vm_generic(){
wr $sys/vm/highmem_is_dirtyable 0
wr $sys/vm/min_free_kbytes $((1024+$msize/1024))
wr $sys/vm/oom_kill_allocating_task 0
wr $sys/vm/oom_dump_tasks 0
wr $sys/vm/panic_on_oom 0
wr $sys/vm/page-cluster 0
wr $sys/vm/stat_interval 600
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

for x in /sys/block/*; do

queue="$x/queue"

w="wrl $queue"

$w/max_sectors_kb $(read $queue/max_hw_sectors_kb)
$w/iostats 0
$w/add_random 0
$w/read_ahead_kb 512
$w/nomerges 2
$w/rotational 0
$w/rq_affinity 1

w="wrl $queue/iosched"

case $(read $queue/scheduler) in

*deadline*)

wrl $queue/scheduler deadline

# deadline specific tuning

$w/fifo_batch 8
$w/writes_starved 2
$w/read_expire 500
$w/write_expire 5000
$w/front_merges 0;;

*cfq*)

wrl $queue/scheduler cfq

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
