#!/bin/bash

TIME_CYCLE=             # periodic duration (sec) scan the noso-go log file
                        # this parameter can be overwrite by a equivalent in file params.txt

#------------------------------------------------------------------------------#

noso_go_logfile=noso-go.log
ngstuff_logfile=killing.log
log_lines_count=60  # number of latest log lines
events_duration=60  # duration (sec) the events occur

#------------------------------------------------------------------------------#

[ -f params.txt ] && params="$(cat params.txt)"
params=$(echo "$params" \
    | sed 's/#.*$//g' \
    | sed 's/^ *//;s/ *$//;s/  */ /g;' \
    | grep -E -v '^$' \
    | awk '!seen[$0]++')
    # remove commented part of lines (from # charater to the end of line);
    # trim leading spaces (1), trim trailing spaces (2), and replace a group of
    # spaces with a single space (3);
    # remove empty lines;
    # remove duplicated lines preserved order;

reNUM='^[0-9]+$'

aTIME_CYCLE=$(echo "$params" | grep -E '^TIME_CYCLE' | tail -1 | sed -n -e 's/^TIME_CYCLE *= *//p')
if [[ "$aTIME_CYCLE" =~ $reNUM ]] ; then
   TIME_CYCLE=$aTIME_CYCLE
fi

#------------------------------------------------------------------------------#

if [ -z "$TIME_CYCLE" ]; then
    printf "[%s]The variable 'TIME_CYCLE' is required to be set!\n" \
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

function kill_miner() {
    local oldminer=$(pidof noso-go)
    if [ -n "$oldminer" ]; then
        printf "[%s]Trying to kill the sick noso-go[pid=%s]\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            $oldminer \
            | tee -a $ngstuff_logfile
        if [ -z "$(kill $oldminer &>/dev/null)" ]; then
            printf "[%s]Killed succesfully the noso-go process\n" \
                "$(date +'%Y/%m/%d %H:%M:%S')" \
                | tee -a $ngstuff_logfile
        fi
    else
        printf "[%s]The noso-go process has been terminated already\n" \
            "$(date +'%Y/%m/%d %H:%M:%S')" \
            | tee -a $ngstuff_logfile
    fi
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

[ -f "$ngstuff_logfile" ] && mv $ngstuff_logfile ${ngstuff_logfile}-last

printf "[%s]================================================================================\n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]Scan the noso-go log in periodic %s seconds to detect dead events as they occur.\n" "$(date +'%Y/%m/%d %H:%M:%S')" $TIME_CYCLE | tee -a $ngstuff_logfile
printf "[%s]That sick noso-go process be killed. In the combination with 'ngExec.sh', a new \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]noso-go process will be invoked appropriately. Detecting dead events includes:  \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'BANNED'                                                                      \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'POOLFULL'                                                                    \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'ALREADYCONNECTED'                                                            \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'PING 0'                                                                      \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'Watchdog Triggered'                                                          \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- 'i/o timeout'                                                                 \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]-----------------------------------PARAMETERS-----------------------------------\n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]                                                                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]- TIME_CYCLE=$TIME_CYCLE (seconds)                                              \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]                                                                                \n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile
printf "[%s]================================================================================\n" "$(date +'%Y/%m/%d %H:%M:%S')" | tee -a $ngstuff_logfile

last_detecting_time="2021/01/01 00:00:01"

while true; do
    [ ! -f "$noso_go_logfile" ] && sleep $TIME_CYCLE && continue
    last_log_lines=$(tail -n $log_lines_count $noso_go_logfile)
    rt_lines_count=$(echo "$last_log_lines" | wc -l)
    dt_lines_count=1
    while [ $dt_lines_count -le $rt_lines_count ]; do
        latest_log_time=$( \
            echo "$last_log_lines" \
            | tail -n $dt_lines_count \
            | head -1 \
            | grep -o -E "^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}")
        [ -n "$latest_log_time" ] && break
        dt_lines_count=$(expr $dt_lines_count + 1)
    done
    [ -z "$latest_log_time" ] && sleep $TIME_CYCLE && continue
    elapsed_secs=$(timediff_in_second "$last_detecting_time" "$latest_log_time")
    [ $elapsed_secs -le 0 ] && sleep $TIME_CYCLE && continue

    # pre-process the 'Watchdog Triggered' if present
    # last_log_lines=$(echo "$last_log_lines" | sed -E '
    #     /( ###################)$/{                                             # if match the 1st line pattern
    #         $!{                                                                #   if not on the last line
    #             N                                                              #       append the next line
    #             /(\nWatchdog Triggered)$/{                                     #       if match the 2nd line pattern
    #                 s/\n//                                                     #           remove newline
    #                 $!{                                                        #           if not on the last line
    #                     N                                                      #               append the next line
    #                     /(\n###################)$/{                            #               if match the 3rd line pattern
    #                         s/\n//                                             #                   remove newline
    #                     }
    #                 }
    #             }
    #         }
    #     }')
    last_log_lines=$(echo "$last_log_lines" | sed -E '
        /( ###################)$/{
            $!{
                N;
                /(\nWatchdog Triggered)$/{
                    s/\n//;
                    $!{
                        N;
                        /(\n###################)$/{
                            s/\n//
                        } 
                    }
                }
            }
        }
    ')

    detect_event_occurrence "$last_log_lines" "BANNED" "( <- BANNED)$" "$last_detecting_time" 1
    [ "$?" -eq 1 ] && kill_miner

    detect_event_occurrence "$last_log_lines" "POOLFULL" "( <- POOLFULL)$" "$last_detecting_time" 1
    [ "$?" -eq 1 ] && kill_miner

    detect_event_occurrence "$last_log_lines" "ALREADYCONNECTED" "( <- ALREADYCONNECTED)$" "$last_detecting_time" 3
    [ "$?" -eq 1 ] && kill_miner

    detect_event_occurrence "$last_log_lines" "Watchdog Triggered" "( ###################Watchdog Triggered)" "$last_detecting_time" 1
    [ "$?" -eq 1 ] && kill_miner

    detect_event_occurrence "$last_log_lines" "PING 0" "( -> PING 0)$" "$last_detecting_time" 5
    [ "$?" -eq 1 ] && kill_miner

    detect_event_occurrence "$last_log_lines" "i/o timeout" "( Error (.*) i/o timeout)$" "$last_detecting_time" 10
    [ "$?" -eq 1 ] && kill_miner

    last_detecting_time="$latest_log_time"
    sleep $TIME_CYCLE
done
