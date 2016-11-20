#!/bin/bash

read -r -a pids <<< `ls -l /proc/ | awk '/[0-9]+$/ {print $9}' | awk '/[0-9]/'`


function get_prop_from_file {
	sed -n -e "s/^$2:\s*//p" $1
}

function extract_number {
        echo $1 | sed 's/[^0-9]*//g'
}

MEMTOTAL=`get_prop_from_file /proc/meminfo MemTotal`
MEMFREE=`get_prop_from_file /proc/meminfo MemFree`
MEMTOTALNUM=`extract_number $MEMTOTAL`
MEMFREENUM=`extract_number $MEMFREE`
echo Total Memory: $MEMTOTAL
echo Used Memory: $(($MEMTOTALNUM - $MEMFREENUM)) kB
echo Free Memory: $MEMFREE

OUTPUT="PID USER PR VIRT S %CPU %MEM\n\n"

for pid in "${pids[@]}"
do
    USERID=`get_prop_from_file /proc/$pid/status Uid|awk '{print $1}'`
    PRIORITY=`awk '{print $18}' /proc/$pid/stat`
    VIRTUALMEM=`awk '{print $23}' /proc/$pid/stat`
    STATE=`awk '{print $3}' /proc/$pid/stat`

    UPTIME=`awk '{print $1}' /proc/uptime`
    UPTIME=`extract_number $UPTIME`

    STARTTIME=`awk '{print $22}' /proc/$pid/stat`
    UTIME=`awk '{print $14}' /proc/$pid/stat`
    STIME=`awk '{print $15}' /proc/$pid/stat`
    HERTZ=`getconf CLK_TCK`
    TOTALTIME=$(($UTIME + $STIME))
    SECONDS=$(($UPTIME - ($STARTTIME / $HERTZ)))
#this is crap
    CPUPERCENT=$((100 * $TOTALTIME / $HERTZ / $SECONDS))

    MEMPERCENT=$(($VIRTUALMEM / 1024*100 / $MEMTOTALNUM))


    OUTPUT="$OUTPUT\n$pid $USERID $PRIORITY $VIRTUALMEM $STATE $CPUPERCENT $MEMPERCENT"
done

echo -ne $OUTPUT | column -t





