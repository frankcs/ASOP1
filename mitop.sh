#!/bin/bash
echo "mitop está ejecutando ... espere por favor"

# Usada para extraer el valor de una propiedad de aquellos ficheros que tienen el formato de un clave/valor por línea
function get_prop_from_file {
    sed -n -e "s/^$2\s*//p" $1
}

# Usada para extraer el valor númerico de una línea de texto
function extract_number {
    echo $1 | sed 's/[^0-9]*//g'
}

# Leyendo todos los nombres de directorios de /proc que terminan en números
# se dejan en el array pids que luego se itera para obtener información de cada uno de los procesos
read -r -a pids <<< `ls -l /proc/ | awk '/[0-9]+$/ {print $9}' | awk '/[0-9]/'`

# Inicializando variables que se usan en el bloque de datos generales
MEMTOTAL=`get_prop_from_file /proc/meminfo MemTotal:`
MEMFREE=`get_prop_from_file /proc/meminfo MemFree:`
MEMTOTALNUM=`extract_number $MEMTOTAL`
MEMFREENUM=`extract_number $MEMFREE`
PROCESSES=${#pids[@]}
TOTALUSAGE=0

# Declarando un array asociativo para poner los datos de cada proceso 
declare -A pdata

# Tomando el tiempo inicial para calcular luego el porcentaje de uso de cpu
INITIME=`awk '{print $1}' /proc/uptime`

# Iterando sobre el array de procesos y tomando los datos requeridos de cada uno
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

# Haciendo la pausa para la nueva toma de datos (solo datos relativos al uso de CPU)
sleep 1

# Recogiendo el tiempo fianl para calcular el tiempo transcurrido entre las dos recogidas de datos
ENDTIME=`awk '{print $1}' /proc/uptime`
DIFF=`bc <<< "scale=2; ($ENDTIME - $INITIME)"`

for pid in "${pids[@]}"
do
    if [ -d "/proc/$pid/" ];then    
    read UTIME2 STIME2 <<< $(awk '{print $14" "$15}' /proc/$pid/stat)        
    pdata[$pid, CPUTIME2]=$(($UTIME2 + $STIME2))
    HERTZ=`getconf CLK_TCK`
    # Calculando el porcentaje de uso del procesador por proceso
    pdata[$pid, CPU]=`bc <<< "scale=2; ((${pdata[$pid, CPUTIME2]} - ${pdata[$pid, CPUTIME1]}) / $HERTZ) * 100 / $DIFF"`
    # Incrementando la variable que mantiene el uso total
    TOTALUSAGE=`bc <<< "scale=2; ${pdata[$pid, CPU]} + $TOTALUSAGE"`

    # Componiendo la salida de datos especificos de proceso   
    OUTPUT="$OUTPUT$pid ${pdata[$pid, USER]} ${pdata[$pid, PR]} ${pdata[$pid, VIRT]} ${pdata[$pid, S]} ${pdata[$pid, CPU]} ${pdata[$pid, MEM]} ${pdata[$pid, CPUTIME2]} ${pdata[$pid, COMMAND]}\n"
    fi
done

# Ordenación y filtrado de la salida de acuerdo a los requerimientos
OUTPUT=`echo -ne "$OUTPUT"  | sort -k6rn,6 | head -10` 

# Encabezado de la sección de datos de procesos
HEADINGS="PID USER PR VIRT S %CPU %MEM TIME COMMAND\n"

# Salida del bloque de datos generales
echo "*********************************************************************"
echo Procesos: $PROCESSES
echo Uso CPU: $TOTALUSAGE %
echo Memoria Total: $MEMTOTAL
echo Memoria Utilizada: $(($MEMTOTALNUM - $MEMFREENUM)) kB
echo Memoria Libre: $MEMFREE
echo "*********************************************************************"
# Salida del bloque de datos de procesos
echo -ne "$HEADINGS$OUTPUT\n" | column -t
echo "*********************************************************************"