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
        printf "\t: ONLINE"
        if [ -z "$resp_text" ]; then
            printf "\tno pool and miner information responded"
            printf "\t(%s:%s %s)\n" $host $port $pass
            continue
        fi
        if [ ${resp_text:0:6} == "STATUS" ]; then
            status=($resp_text)
            percentfee=$(echo "scale=2; ${status[2]} / 100" | bc -l)
            printf "\thrate: %s; fee: %s%%; share: %s%%; miner: %s\n" \
                "${status[1]}" "$percentfee" "${status[3]}" "${status[4]}"
            found_count=0
            conne_count=0
            for i in "${!USERS[@]}"; do
                miner_stat=$( \
                    echo $resp_text \
                    | grep -o -E "${USERS[i]}:[0-9]*:(-?)[0-9]*:[0-9]*")
                if [ ! -z "$miner_stat" ]; then
                    found_count="$(expr $found_count + 1)"
                    printf "\t%-55s" $miner_stat
                    pool_text="$( \
                        echo "$pass ${USERS[0]} STATUS" \
                        | timeout $probing_duration nc -w $probing_duration $host $port)"
                    if [ "${pool_text:0:16}" = "ALREADYCONNECTED" ]; then
                        conne_count="$(expr $conne_count + 1)"
                        printf " <- CONNECTED\n" $miner_stat
                    else
                        printf "\n"
                    fi
                else
                    printf "\t%-55s -> NOT FOUND\n" ${USERS[i]}
                fi
            done
            if [ ${#USERS[@]} -gt 0 ]; then
                printf "\t%55s\t%d / %d / %d\n" \
                    "SUMMARY (mining / found / total users):" \
                    $conne_count $found_count ${#USERS[@]}
            fi
        else
            printf "\tno pool and miner information responded (${resp_text::})"
            printf "\t(%s:%s %s)\n" $host $port $pass
        fi
    elif [ "$exit_code" -eq 1 ]; then
        printf "\t: OFFLINE"
        printf "\t(%s:%s %s)\n" $host $port $pass
    elif [ "$exit_code" -eq 124 ]; then
        printf "\t: TIMEOUT ($probing_duration secs)"
        printf "\t(%s:%s %s)\n" $host $port $pass
    else
        printf "\t: N/A STATUS"
        printf "\t(%s:%s %s)\n" $host $port $pass
    fi
done <<< "$POOLS"
