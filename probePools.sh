#!/bin/bash

POOLS=$(cat << EOF
# List of mining pools. This list can be combined with pools.txt
# The 1st pool in list has higher priority than the 2nd one, and so on the next
# pools. The pool fallback mechanism follows this order.
#
# LINE-FORMATION (#-prefix lines being ignored):
# NAME HOST/IP PORT PASSWORD
#
#MyOwnPool  <MY_POOL_IP>            8082    <MY_POOL_PASS>
#localhost  127.0.0.1               8082    password
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

probing_duration=30                 # timeout duration (sec) for probing pool alive

[ -f pools.txt ] && POOLS=$(printf "%s\n%s" "$(cat pools.txt)" "$POOLS")
POOLS=$(echo "$POOLS" \
    | sed 's/#.*$//g;s/\t/ /g;s/^ *//;s/ *$//;s/  */ /g;/^$/d;' \
    | awk '!seen[$0]++')
    # 1/remove commented part from # charater to the end of line (1), replace a
    # tab character by a space (2), trim line's leading spaces (3), trim line's
    # trailing spaces (4), replace a group of spaces with a single space (5),
    # remove empty lines (6);
    # 2/remove duplicated lines preserved order;
[ ${#POOLS[@]} -eq 0 ] && printf "no pool provided\n" && exit 0

[ -f users.txt ] && USERS=$(printf "%s\n%s" "$(cat users.txt)" "$USERS")
USERS=$(echo "$USERS" \
    | sed 's/#.*$//g;s/\t/ /g;s/^ *//;s/ *$//;s/  */ /g;/^$/d;' \
    | awk '!seen[$0]++')
    # 1/remove commented part from # charater to the end of line (1), replace a
    # tab character by a space (2), trim line's leading spaces (3), trim line's
    # trailing spaces (4), replace a group of spaces with a single space (5),
    # remove empty lines (6);
    # 2/remove duplicated lines preserved order;
USERS=($USERS)                      # convert list to array of users

all_found_count=0
all_conne_count=0
all_hrate_total=0
all_balan_total=0

while read -r line
do
    line=($line)
    name="${line[0]}"
    printf "POOL %s" $name
    host="${line[1]}"
    port="${line[2]}"
    pass="${line[3]}"

    resp_text="$( \
        echo "$pass gcarreno-main STATUS" \
        | timeout $probing_duration nc -w $probing_duration $host $port)"
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        # printf "\tONLINE"
        if [ -z "$resp_text" ]; then
            printf "\tno pool and miner information responded"
            printf "\t(%s:%s %s)\n" $host $port $pass
            continue
        fi
        if [ ${resp_text:0:6} == "STATUS" ]; then
            status=($resp_text)
            printf "\thrate: %'d fee: %'.2f%% share: %s%% diff.: %'d miners: %'d\n" \
                "${status[1]}" "$(echo 'scale=2; '"${status[2]}"' / 100' | bc -l)" \
                "${status[3]}" "${status[4]}" "${status[5]}"
            found_count=0
            conne_count=0
            hrate_total=0
            balan_total=0
            for i in "${!USERS[@]}"; do
                miner_stat=$( \
                    echo $resp_text \
                    | grep -o -E "${USERS[i]}:[0-9]*:(-?)[0-9]*:[0-9]*")
                if [ -n "$miner_stat" ]; then
                    found_count="$(expr $found_count + 1)"
                    printf "\t%-55s" $miner_stat
                    state=${miner_stat#"${USERS[i]}:"}      # remove user part
                    balan=$(echo "$state" | grep -o -E '^([0-9]*)')
                    hrate=$(echo "$state" | grep -o -E '([0-9]*)$')
                    hrate_total=$(expr $hrate_total + $hrate)
                    balan_total=$(expr $balan_total + $balan)
                    pool_text="$( \
                        echo "$pass ${USERS[0]} STATUS" \
                        | timeout $probing_duration nc -w $probing_duration $host $port)"
                    if [ "${pool_text:0:16}" = "ALREADYCONNECTED" ]; then
                        conne_count="$(expr $conne_count + 1)"
                        printf " <-    CONNECTED\n"
                    else
                        printf "\n"
                    fi
                else
                    printf "\t%-55s ->    NOT FOUND\n" ${USERS[i]}
                fi
            done
            if [ ${#USERS[@]} -gt 0 ]; then
                printf "%79s\n" "(mining/connected/total)"
                printf "%63s%16s\n" \
                    "Sub-Total: - num. of users:" \
                    "$(printf '%d/%d/%d' \
                        $conne_count $found_count ${#USERS[@]})"
                printf "%63s%'16d\n" "- hashrate:" $hrate_total
                printf "%63s%'16.08f\n" "- balance:" $(echo $balan_total' / 100000000' | bc -l)
            fi
            all_found_count=$(expr $all_found_count + $found_count)
            all_conne_count=$(expr $all_conne_count + $conne_count)
            all_hrate_total=$(expr $all_hrate_total + $hrate_total)
            all_balan_total=$(expr $all_balan_total + $balan_total)
        else
            printf "\tno pool and miner information responded (${resp_text::})"
            printf "\t(%s:%s %s)\n" $host $port $pass
        fi
    elif [ "$exit_code" -eq 1 ]; then
        printf "\tOFFLINE"
        printf "\t(%s:%s %s)\n" $host $port $pass
    elif [ "$exit_code" -eq 124 ]; then
        printf "\tTIMEOUT ($probing_duration secs)"
        printf "\t(%s:%s %s)\n" $host $port $pass
    else
        printf "\tN/A STATUS"
        printf "\t(%s:%s %s)\n" $host $port $pass
    fi
done <<< "$POOLS"
if [ ${#POOLS[@]} -gt 1 ] && [ ${#USERS[@]} -gt 0 ]; then
    printf "%s\n" "-------------------------------------------------------------------------------"
    printf "%79s\n" \
        "(MINING/CONNECTED/TOTAL)"
    printf "%63s%16s\n" \
        "${#POOLS[@]} POOLS GRAND-TOTAL: - USERS #:" \
        "$(printf '%d/%d/%d' \
            $all_conne_count $all_found_count ${#USERS[@]})"
    printf "%63s%'16d\n" "- HASHRATE:" $all_hrate_total
    printf "%63s%'16.08f\n" "- BALANCE:" $(echo $all_balan_total' / 100000000' | bc -l)
fi
