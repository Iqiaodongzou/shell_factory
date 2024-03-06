#!/bin/bash
# Function: This scripts function is to query device ip and trap status from traplog file
# This script will create two file perday at basedir: 
#   1. ${current_date}_mib_mode.txt
#   2. ${current_date}_trap_status.txt
# Author: zouqd@opengoss.com
# Version: 0.1
# Update-Time: 2024-01-28 Wed 11:20:56 CST
 
basedir="/opt/ponoss/trap_snmp/monitor/"
directory="/opt/ponoss/trap_snmp/var/log/"
suffix=".log.*"
keyword="raw_trap"
current_date=$(date +%Y%m%d)
current_time=$(date +%H%M%S)
recordfile="${basedir}${current_date}.record"
mibmode="${basedir}${current_date}_mib_mode.txt"
trapstatus="${basedir}${current_date}_trap_status.txt"
pattern1="1.3.6.1.4.1.2011.2.294"
pattern2="1.3.6.1.4.1.2011.2.115"
pattern3="1.3.6.1.4.1.2011.2.133"
flag=false
ip=""


handle_parts() {
    filename=$1
    echo "[ $(date +%Y%m%d)$(date +%H%M%S) ] processing filename: $filename handle parts =====>"
    key=$(echo $filename | rev | cut -d '/' -f1 | rev)
    file_rows=$(wc -l < "$filename")
    file_num=100
    file_num_row=$((${file_rows} + 9))
    every_file_row=$(($file_num_row/${file_num}))
    result=$(split -d -a 4 -l ${every_file_row} $filename $filename.tmp.parts.)
    filelist=$(find "$directory" -type f -name "$filename.tmp.parts.*" ! -name "*.swp")
    find "$directory" -type f -name "$key*tmp.parts.*" ! -name "*.swp" | while read file; do {
        handle_status $file
        rm $file
    } &
    done
    wait
    combine_status $key
    #sort -u "$mibmode" > "$tempfileb"
}

handle_status() {
    item=$1
    echo "[ $(date +%Y%m%d)$(date +%H%M%S) ] processing filename: $item handle status =====>"
    grep "$keyword" "$item" >> "$item.record"
    while IFS= read -r line; do
        header_pattern='raw_trap,"([0-9]{1,3}\.){3}[0-9]{1,3}'
        header=$(echo $line| grep -oE "$header_pattern")
        ip=$(echo "$header" | sed 's/raw_trap,"//g')
        if [[ $line =~ $pattern1 ]]; then
            flag=2
            echo "$ip $flag" >> $item.mib
        elif [[ $line =~ $pattern2 ]]; then
            flag=2
            echo "$ip $flag" >> $item.mib
        elif [[ $line =~ $pattern3 ]]; then
            flag=2
            echo "$ip $flag" >> $item.mib
        else
            flag=1
            echo "$ip $flag" >> $item.mib
        fi
    echo "$ip 1" >> $item.trap
    done < "$item.record"
    rm "$item.record"
}

combine_status() {
    key=$1
    #sleep 480
    echo "[ $(date +%Y%m%d)$(date +%H%M%S) ] processing filekey: $key combine status =====>"
    sleep 120
    output_file_mib="$directory$key.mib"
    output_file_trap="$directory$key.trap"
    find "$directory" -type f -name "$key.*.mib" | while read file; do
        cat "$file" >> $output_file_mib
        rm "$file"
    done
    find "$directory" -type f -name "$key.*.trap" | while read file; do
        cat "$file" >> $output_file_trap
        rm "$file"
    done
}

combine_alldata() {
    echo "[ $(date +%Y%m%d)$(date +%H%M%S) ] now start to combine all data =====> "
    output_file_mib="$directory${current_date}_mib_mode.txt"
    output_file_trap="$directory${current_date}_trap_status.txt"
    find "$directory" -type f -name "*.mib" | while read file; do
        cat "$file" >> $output_file_mib
        tempfilea=$(mktemp)
        sort -u "$output_file_mib" > "$tempfilea"
        mv "$tempfilea" "$output_file_mib"
        cat "$output_file_mib" >> "$mibmode"
        rm "$output_file_mib"
        rm "$file"
    done
    find "$directory" -type f -name "*.trap" | while read file; do
        cat "$file" >> $output_file_trap
        tempfileb=$(mktemp)
        sort -u "$output_file_trap" > "$tempfileb"
        mv "$tempfileb" "$output_file_trap"
        cat "$output_file_trap" >> "$trapstatus"
        rm "$output_file_trap"
        rm "$file"
    done
        tempfilec=$(mktemp)
        sort -u "$mibmode" > "$tempfilec"
        mv "$tempfilec" "$mibmode"
        tempfiled=$(mktemp)
        sort -u "$trapstatus" > "$tempfiled"
        mv "$tempfiled" "$trapstatus"
}

process_start(){
    echo "[ $(date +%Y%m%d)$(date +%H%M%S) ] trap logfile parser starting now =====>"
    find "$directory" -type f -name "*$suffix" ! -name "*.swp" ! -name "*.tmp.*" ! -name "*crash.*" ! -name "*.sasl.log" ! -name "*.all.log" ! -name "*.error.log"| while read file; do {
        handle_parts $file
    }
    wait
    done
    combine_alldata
    echo "[ $(date +%Y%m%d)$(date +%H%M%S) ] trap logfile parser was finished now =====>"
}

export -f handle_status

process_start
