#!/bin/bash
echo "mytop is running ... please wait"

function get_prop_from_file {
	sed -n -e "s/^$2\s*//p" $1
}

function extract_number {
    echo $1 | sed 's/[^0-9]*//g'
}

read -r -a pids <<< `ls -l /proc/ | awk '/[0-9]+$/ {print $9}' | awk '/[0-9]/'`

MEMTOTAL=`get_prop_from_file /proc/meminfo MemTotal:`
MEMFREE=`get_prop_from_file /proc/meminfo MemFree:`
MEMTOTALNUM=`extract_number $MEMTOTAL`
MEMFREENUM=`extract_number $MEMFREE`
PROCESSES=${#pids[@]}
TOTALUSAGE=0



declare -A pdata

INITIME=`awk '{print $1}' /proc/uptime`

for pid in "${pids[@]}"
do
	if [ -d "/proc/$pid/" ];then

    pdata[$pid, USER]=`get_prop_from_file /proc/$pid/status Uid:|awk '{print $1}'`   
    read COMMAND PRIORITY VIRTUALMEM STATE UTIME STIME <<< $(awk '{print $2" "$18" "$23" "$3" "$14" "$15}' /proc/$pid/stat)

    pdata[$pid, COMMAND]=$COMMAND
    pdata[$pid, CPUTIME1]=$(($UTIME + $STIME))
    pdata[$pid, MEM]=`bc <<< "scale=2; $VIRTUALMEM / 1024*100 / $MEMTOTALNUM"`        
    pdata[$pid, PR]=$PRIORITY
    pdata[$pid, VIRT]=$VIRTUALMEM
    pdata[$pid, S]=$STATE    

	fi
done

sleep 1

ENDTIME=`awk '{print $1}' /proc/uptime`
DIFF=`bc <<< "scale=2; ($ENDTIME - $INITIME)"`

for pid in "${pids[@]}"
do
	if [ -d "/proc/$pid/" ];then    
    read UTIME2 STIME2 <<< $(awk '{print $14" "$15}' /proc/$pid/stat)        
    pdata[$pid, CPUTIME2]=$(($UTIME2 + $STIME2))
    HERTZ=`getconf CLK_TCK`
    pdata[$pid, CPU]=`bc <<< "scale=2; ((${pdata[$pid, CPUTIME2]} - ${pdata[$pid, CPUTIME1]}) / $HERTZ) * 100 / $DIFF"`
    TOTALUSAGE=`bc <<< "scale=2; ${pdata[$pid, CPU]} + $TOTALUSAGE"`
   
    OUTPUT="$OUTPUT$pid ${pdata[$pid, USER]} ${pdata[$pid, PR]} ${pdata[$pid, VIRT]} ${pdata[$pid, S]} ${pdata[$pid, CPU]} ${pdata[$pid, MEM]} ${pdata[$pid, CPUTIME2]} ${pdata[$pid, COMMAND]}\n"
	fi
done

HEADINGS="PID USER PR VIRT S %CPU %MEM TIME COMMAND\n"

echo "*********************************************************************"
echo Processes: $PROCESSES
echo CPU Usage: $TOTALUSAGE %
echo Total Memory: $MEMTOTAL
echo Used Memory: $(($MEMTOTALNUM - $MEMFREENUM)) kB
echo Free Memory: $MEMFREE
echo "*********************************************************************"
OUTPUT=`echo -ne "$OUTPUT"  | sort -k6rn,6 | head -10` 
echo -ne "$HEADINGS$OUTPUT\n" | column -t
echo "*********************************************************************"



