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

#OUTPUT="PID USER PR VIRT S CPUTIME %MEM\n"

declare -a pdata

for pid in "${pids[@]}"
do
	if [ -d "/proc/$pid/" ];then
    USERID=`get_prop_from_file /proc/$pid/status Uid|awk '{print $1}'`   
    read PRIORITY VIRTUALMEM STATE UTIME STIME<<< $(awk '{print $18" "$23" "$3" "$14" "$15}' /proc/$pid/stat)
    TOTALTIME=$(($UTIME + $STIME))    

    MEMPERCENT=`bc <<< "scale=2; $VIRTUALMEM / 1024*100 / $MEMTOTALNUM"`
    pdata[$pid]="$pid $USERID $PRIORITY $VIRTUALMEM $STATE $TOTALTIME $MEMPERCENT"
    echo ${pdata[$pid]}

    #OUTPUT="$OUTPUT\n$pid $USERID $PRIORITY $VIRTUALMEM $STATE $TOTALTIME $MEMPERCENT\n"
	fi
done

#echo -ne $OUTPUT | column -t





