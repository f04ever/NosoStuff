#!/bin/bash

CPU=                    # CPUs count using for mining
                        # this parameter can be overwrite by a equivalent in file params.txt
                        #
SWITCH_DURATION=        # duration (sec) for mining in non-preferred pools,
                        # zero means no non-preferred mining
                        # this parameter can be overwrite by a equivalent in file params.txt

POOLS=$(cat << EOF
# List of mining pools. This list can be combined with pools.txt
# The 1st pool in list has higher priority than the 2nd one, and so on the next
# pools. The pool fallback mechanism follows this order.
#
# LINE-FORMATION (#-prefix lines being ignored):
# NAME HOST/IP PORT PASSWORD
#
#localhost  127.0.0.1               8082    a_password
#MyOwnPool  <MY_POOL_IP>            8082    <MY_POOL_PASS>
EOF
)

USERS=$(cat << EOF
# List of mining users (wallet address/ alias). This list can be combined with users.txt
# The 1st user in list has higher priority then the 2nd one, and so on the next
# users. The user fallback mechanism follow this order.
#
# LINE-FORMATION (#-prefix lines being ignored): one user per line
#
EOF
)

#------------------------------------------------------------------------------#

log_lines_count=60                  # number of latest log lines be used in detecting
events_duration=60                  # duration that events might occur
probing_duration=30                 # timeout duration (sec) for probing pool alive
noso_go_logfile=noso-go.log
ngstuff_logfile=pooling.log

#------------------------------------------------------------------------------#

[ -f pools.txt ] && POOLS=$(printf "%s\n%s" "$(cat pools.txt)" "$POOLS")
POOLS=$(echo "$POOLS" \
    | sed 's/#.*$//g;s/\t/ /g;s/^ *//;s/ *$//;s/  */ /g;/^$/d;' \
    | awk '!seen[$0]++')
    # 1/remove commented part from # charater to the end of line (1), replace a
    # tab character by a space (2), trim line's leading spaces (3), trim line's
    # trailing spaces (4), replace a group of spaces with a single space (5),
    # remove empty lines (6);
    # 2/remove duplicated lines preserved order;

[ -f users.txt ] && USERS=$(printf "%s\n%s" "$(cat users.txt)" "$USERS")
USERS=$(echo "$USERS" \
    | sed 's/#.*$//g;s/\t/ /g;s/^ *//;s/ *$//;s/  */ /g;/^$/d;' \
    | awk '!seen[$0]++')
    # 1/remove commented part from # charater to the end of line (1), replace a
    # tab character by a space (2), trim line's leading spaces (3), trim line's
    # trailing spaces (4), replace a group of spaces with a single space (5),
    # remove empty lines (6);
    # 2/remove duplicated lines preserved order;

[ -f params.txt ] && params="$(cat params.txt)"
params=$(echo "$params" \
    | sed 's/#.*$//g;s/\t/ /g;s/^ *//;s/ *$//;s/  */ /g;/^$/d;' \
    | awk '!seen[$0]++')
    # 1/remove commented part from # charater to the end of line (1), replace a
    # tab character by a space (2), trim line's leading spaces (3), trim line's
    # trailing spaces (4), replace a group of spaces with a single space (5),
    # remove empty lines (6);
    # 2/remove duplicated lines preserved order;
aCPU=$(echo "$params" | grep -E '^CPU' | tail -1 | sed -n -e 's/^CPU *= *//p')
if [[ "$aCPU" =~ ^[0-9]+$ ]] ; then
   CPU=$aCPU
fi
aSWITCH_DURATION=$(echo "$params" | grep -E '^SWITCH_DURATION' | tail -1 | sed -n -e 's/^SWITCH_DURATION *= *//p')
if [[ "$aSWITCH_DURATION" =~ ^[0-9]+$ ]] ; then
   SWITCH_DURATION=$aSWITCH_DURATION
fi

#------------------------------------------------------------------------------#

if [ -z "$CPU" ]; then
    printf "[%s]The variable 'CPU' is required to be set!\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        | tee -a $ngstuff_logfile
    exit 0
fi

if [ -z "$SWITCH_DURATION" ]; then
    printf "[%s]The variable 'SWITCH_DURATION' is required to be set!\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        | tee -a $ngstuff_logfile
    exit 0
fi

if [ -z "$POOLS" ]; then
    printf "[%s]No pool provided\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        | tee -a $ngstuff_logfile
    exit 0
fi

if [ -z "$USERS" ]; then
    printf "[%s]No wallet provided\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        | tee -a $ngstuff_logfile
    exit 0
fi
#------------------------------------------------------------------------------#

function timediff_in_second() {
    local elapsed_secs=
    if [ "${OSTYPE:0:6}" = "darwin" ]; then
        elapsed_secs=$(expr $(date -jf '%Y/%m/%d %H:%M:%S' "$2" +%s) - $(date -jf '%Y/%m/%d %H:%M:%S' "$1" +%s))
    elif [ "${OSTYPE:0:5}" = "linux" ]; then
        elapsed_secs=$(expr $(date -d "$2" +%s) - $(date -d "$1" +%s))
    else
        printf "[%s]Not implement yet the time difference calculation in the %s\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            "$OSTYPE" \
            | tee -a $ngstuff_logfile
        exit 0
    fi
    echo $elapsed_secs
}

function detect_event_occurrence() {
    local log_lines="$1"
    local event_name="$2"
    local event_pattern="$3"
    local previous_time="$4"
    local max_occurrences="$5"
    local latest_events=$(echo "$log_lines" | grep -E "$event_pattern")
    if [ -n "$latest_events" ]; then
        local events_count=$(echo "$latest_events" | wc -l)
        if [ $events_count -ge $max_occurrences ]; then
            local latest_time=$( \
                echo "$latest_events" \
                | tail -1 \
                | grep -o -E "^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}")
            local diff_latest_prevous=$(timediff_in_second "$previous_time" "$latest_time")
            if [ $diff_latest_prevous -gt 0 ]; then
                local diff_present_latest=$(timediff_in_second "$latest_time" "$(date +'%Y/%m/%d %H:%M:%S')")
                if [ "${OSTYPE}" = "linux-android" ]; then
                    diff_present_latest=$(timediff_in_second "$latest_time" "$(date -u +'%Y/%m/%d %H:%M:%S')")
                fi
                if [ $diff_present_latest -le $events_duration ]; then
                    printf "[%s]The \`%s\` has occurred %s times last %s seconds\n" \
                        "$(date +'%Y/%m/%d %H:%M:%S')" \
                        "$event_name" \
                        $events_count \
                        $diff_present_latest \
                        | tee -a $ngstuff_logfile
                    return 1
                fi
            fi
        fi
    fi
    return 0
}

select_pool_user_selected=
function select_pool_user_by_pool_statistics() {
    select_pool_user_selected=
    local pool_name=$1
    local pool_host=$2
    local pool_port=$3
    local pool_pass=$4
    local pool_user="gcarreno-main"
    local pool_text="$( \
        echo "$pool_pass $pool_user STATUS" \
        | timeout $probing_duration nc -w $probing_duration $pool_host $pool_port)"
    local pool_code=$?
    if [ $pool_code -eq 0 ]; then
        printf "[%s]Pool %s is online!\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            $pool_name \
            | tee -a $ngstuff_logfile
        printf "[%s]Probing users in pool %s ...\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            $pool_name \
            | tee -a $ngstuff_logfile
        for user in "${USERS[@]}"; do
            local miner_stat=$(echo $pool_text \
                | grep -o -E "$user:[0-9]*:(-?)[0-9]*:[0-9]*")
            if [ -n "$miner_stat" ]; then
                printf "[%s]User %s is mining in pool %s. Skip!\n" \
                    "$(date +'%Y/%m/%d %H:%M:%S')" \
                    $user $pool_name \
                    | tee -a $ngstuff_logfile
            else
                printf "[%s]Found! User %s seems not in pool %s\n" \
                    "$(date +'%Y/%m/%d %H:%M:%S')" \
                    $user $pool_name \
                    | tee -a $ngstuff_logfile
                select_pool_user_selected="$user"
                return 1
            fi
        done
        printf "[%s]All users are mining in pool %s\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            $pool_name \
            | tee -a $ngstuff_logfile
    else
        printf "[%s]Pool %s seems unavailable. Next!\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            $pool_name \
            | tee -a $ngstuff_logfile
    fi
    return 0
}
function select_pool_user_by_probing_pool() {
    select_pool_user_selected=
    local pool_name=$1
    local pool_host=$2
    local pool_port=$3
    local pool_pass=$4
    for pool_user in "${USERS[@]}"; do
        local pool_text="$( \
            echo "$pool_pass $pool_user STATUS" \
            | timeout $probing_duration nc -w $probing_duration $pool_host $pool_port)"
        local pool_code=$?
        if [ $pool_code -eq 0 ]; then
            printf "[%s]Pool %s is online!\n" \
                "$(date +'%Y/%m/%d %H:%M:%S')" \
                $pool_name \
                | tee -a $ngstuff_logfile
            if [ "${pool_text:0:16}" = "ALREADYCONNECTED" ]; then
                printf "[%s]User %s is mining in pool %s. Skip!\n" \
                    "$(date +'%Y/%m/%d %H:%M:%S')" \
                    $pool_user $pool_name \
                    | tee -a $ngstuff_logfile
            else
                printf "[%s]Found! User %s seems not mining in pool %s\n" \
                    "$(date +'%Y/%m/%d %H:%M:%S')" \
                    $pool_user $pool_name \
                    | tee -a $ngstuff_logfile
                select_pool_user_selected="$pool_user"
                return 1
            fi
        else
            printf "[%s]Pool %s seems offline\n" \
                "$(date +'%Y/%m/%d %H:%M:%S')" \
                $pool_name \
                | tee -a $ngstuff_logfile
            return 0
        fi
    done
    printf "[%s]All users are mining in pool %s\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        $pool_name \
        | tee -a $ngstuff_logfile
    return 0
}
function select_pool_user() {
    # select_pool_user_by_pool_statistics $1 $2 $3 $4
    select_pool_user_by_probing_pool $1 $2 $3 $4
}

[ -f "$ngstuff_logfile" ] && mv $ngstuff_logfile ${ngstuff_logfile}-last

printf "[%s]================================================================================\n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]Try to restart the 'noso-go' miner based on recent dead events which be scanned \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]from log file. In the combination with the 'ngKill.sh' to maintain the mining   \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]progress more efficient by switching to other wallet addresses, or fallback to  \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]other mining pools, but able keep more resource on the preferred address or pool\n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'BANNED'              --> Fallback other pools                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'POOLFULL'            --> Fallback other pools                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'POOLCLOSING'         --> Fallback other pools                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'ALREADYCONNECTED'    --> Switch other address                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'PING 0'              --> Restart the miner                                   \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'Watchdog Triggered'  --> Restart the miner                                   \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'i/o timeout'         --> Fallback other pools                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'Error in connection' --> Fallback other pools                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]----------------------------------MINING POOLS----------------------------------\n" \
    "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
count=0
while read -r line; do
    count=$(expr $count + 1)
    printf "[%s] %d - %s\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        $count "$line" \
        | tee -a $ngstuff_logfile
    line=($line)
    if [ ${#line[@]} -lt 4 ]; then
        printf "[%s] %d - INVALID POOL CONFIG\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            $count \
            | tee -a $ngstuff_logfile
        exit 0
    fi
done <<< "$POOLS"

printf "[%s]---------------------------------WALLET ADDRESS---------------------------------\n" \
    "$(date +'%Y/%m/%d %H:%M:%S')" \
    | tee -a $ngstuff_logfile
    count=0
while read -r line; do
    count=$(expr $count + 1)
    printf "[%s] %d - %s\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        $count "$line" \
        | tee -a $ngstuff_logfile
done <<< "$USERS"
printf "[%s]-----------------------------------PARAMETERS-----------------------------------\n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]                                                                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- CPU=$CPU                                                                      \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- SWITCH_DURATION=$SWITCH_DURATION (seconds)                                    \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]                                                                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]================================================================================\n" \
    "$(date +'%Y/%m/%d %H:%M:%S')" \
    | tee -a $ngstuff_logfile

USERS=($USERS)

prefPool=($(echo "$POOLS" | head -n 1))
prefUser="${USERS[0]}"

line=($(echo "$POOLS" | head -n 1))
poolName="${line[0]}"
poolHost="${line[1]}"
poolPort="${line[2]}"
poolPass="${line[3]}"
poolUser="${USERS[0]}"

last_detecting_time="2021/01/01 00:00:01"
timeout_pid=

while true; do
    if [ -f "$noso_go_logfile" ]; then
        for ((i = 8 ; i >= 0 ; i--)); do
            if [ -f "${noso_go_logfile}-$i" ]; then
                mv "${noso_go_logfile}-$i" "${noso_go_logfile}-$(expr $i + 1)"
            fi
        done
        mv ${noso_go_logfile} "${noso_go_logfile}-0"
    fi

    if [ "$poolUser" = "$prefUser" ] && [ "$poolName" = "${prefPool[0]}" ]; then
        mining_duration=0
    else
        mining_duration=$SWITCH_DURATION
    fi

    printf "[%s]User %s starts mining on pool %s\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        "$poolUser" "$poolName" \
        | tee -a $ngstuff_logfile
    [ $mining_duration -gt 0 ] && printf "[%s]Mining will take place in %s minutes\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        $(printf "%.2f\n" $(echo "$mining_duration / 60" | bc -l)) \
        | tee -a $ngstuff_logfile
    [ -n "$timeout_pid" ] && trap - INT
    timeout $mining_duration \
        ./noso-go mine \
            --address "$poolHost" \
            --port "$poolPort" \
            --password "$poolPass" \
            --wallet "$poolUser" \
            --cpu "$CPU" &
    timeout_pid=$!
    trap "kill -INT -$timeout_pid && kill $$" INT
    wait $timeout_pid 2>/dev/null
    miner_exit_code=$?
    printf "[%s]Miner process noso-go exited (code=%s)\n" \
        "$(date +'%Y/%m/%d %H:%M:%S')" \
        "$miner_exit_code" \
        | tee -a $ngstuff_logfile
    if [ $mining_duration -gt 0 ]; then
        poolName="${prefPool[0]}"
        poolHost="${prefPool[1]}"
        poolPort="${prefPool[2]}"
        poolPass="${prefPool[3]}"
        poolUser="$prefUser"
        printf "[%s]Preferred user %s retries mining on preferred pool %s\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            $poolUser \
            $poolName \
            | tee -a $ngstuff_logfile
    fi

    last_log_lines=$(tail -n $log_lines_count $noso_go_logfile)

    switch_pool=0
    switch_addr=0

    detect_event_occurrence "$last_log_lines" "ALREADYCONNECTED" "( <- ALREADYCONNECTED)$" "$last_detecting_time" 3
    [ "$?" -eq 1 ] && switch_addr=1

    if [ $switch_addr -eq 1 ]; then
        printf "[%s]Trying to mine to another address\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            | tee -a $ngstuff_logfile
        select_pool_user $poolName $poolHost $poolPort $poolPass
        selected_code=$?
        if [ $selected_code -eq 1 ]; then
            poolUser=$select_pool_user_selected
            continue
        else
            switch_pool=1
        fi
    fi

    detect_event_occurrence "$last_log_lines" "BANNED" "( <- BANNED)$" "$last_detecting_time" 1
    [ "$?" -eq 1 ] && switch_pool=1

    detect_event_occurrence "$last_log_lines" "POOLFULL" "( <- POOLFULL)$" "$last_detecting_time" 1
    [ "$?" -eq 1 ] && switch_pool=1

    detect_event_occurrence "$last_log_lines" "CLOSINGPOOL" "( <- CLOSINGPOOL)$" "$last_detecting_time" 1
    [ "$?" -eq 1 ] && switch_pool=1

    detect_event_occurrence "$last_log_lines" "i/o timeout" "( Error (.*) i/o timeout)$" "$last_detecting_time" 10
    [ "$?" -eq 1 ] && switch_pool=1

    detect_event_occurrence "$last1_log_lines" "Error in connection:  <nil>" "( Error in connection:  <nil>)$" "$last_detecting_time" 10
    [ "$?" -eq 1 ] && switch_pool=1

    if [ $switch_pool -eq 1 ]; then
        printf "[%s]Trying other pools\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            | tee -a $ngstuff_logfile
        # switch_pool=1
        mining_pool=$poolName
        while read -r line; do
            line=($line)
            poolName="${line[0]}"
            poolHost="${line[1]}"
            poolPort="${line[2]}"
            poolPass="${line[3]}"
            [ "$poolName" = "$mining_pool" ] && continue
            printf "[%s]Probing pool %s ...\n" \
                "$(date +'%Y/%m/%d %H:%M:%S')" \
                $poolName \
                | tee -a $ngstuff_logfile
            select_pool_user $poolName $poolHost $poolPort $poolPass
            selected_code=$?
            if [ $selected_code -eq 1 ]; then
                poolUser=$select_pool_user_selected
                switch_pool=0
                break
            fi
        done <<< "$POOLS"

        if [ $switch_pool -eq 1 ]; then
            printf "[%s]No pool available now.\n" \
                "$(date +'%Y/%m/%d %H:%M:%S')" \
                | tee -a $ngstuff_logfile
            poolName="${prefPool[0]}"
            poolHost="${prefPool[1]}"
            poolPort="${prefPool[2]}"
            poolPass="${prefPool[3]}"
            poolUser="$prefUser"
            printf "[%s]User %s will attempt mining on pool %s next minute\n" \
                "$(date +'%Y/%m/%d %H:%M:%S')" \
                $poolUser \
                $poolName \
                | tee -a $ngstuff_logfile
            sleep 60
        fi
    fi
done
