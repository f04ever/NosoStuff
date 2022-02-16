#!/bin/bash

NODES=$(cat << EOF
# List of nodes. This list can be combined with nodes.txt
# LINE FORMATION: NAME HOST/IP PORT
#
# Local-00  127.0.0.1       8080
#
EOF
)

#------------------------------------------------------------------------------#

[ -f nodes.txt ] && NODES=$(printf "%s\n%s" "$(cat nodes.txt)" "$NODES")
NODES=$(echo "$NODES" \
    | sed 's/#.*$//g;s/\t/ /g;s/^ *//;s/ *$//;s/  */ /g;/^$/d;' \
    | awk '!seen[$0]++')
    # 1/remove commented part from # charater to the end of line (1), replace a
    # tab character by a space (2), trim line's leading spaces (3), trim line's
    # trailing spaces (4), replace a group of spaces with a single space (5),
    # remove empty lines (6);
    # 2/remove duplicated lines preserved order;
[ -z "$NODES" ] && printf "no node provided\n" && exit 0

count=0
timeout=10
printf "     %-34s : NODESTATUS PEERS BLOCKS PENDINGS DELTAS HEADERS VERSION UTC-TIME MNs-HASH MNs-COUNT\n" "$(printf '%s(%s:%s)' 'NODENAME' 'HOST/IP' 'PORT')"
while read -r line
do
    line="${line#"${line%%[![:space:]]*}"}" # remove leading whitespace characters
    line="${line%"${line##*[![:space:]]}"}" # remove trailing whitespace characters
    [ -z "$line" ] && continue              # ignore empty lines
    [ ${line:0:1} == "#" ] && continue      # ignore commented lines
    line=($line)                            # convert to array of info
    name="${line[0]}"
    host="${line[1]}"
    [ -z "$host" ] && continue              # ignore if no host specified
    port="${line[2]}"
    printf "%2s - %-34s : " $count "$(printf '%s(%s:%s)' $name $host $port)"
    resp_text="$(echo 'NODESTATUS' | timeout $timeout nc -w $timeout $host $port)"
    resp_code=$?
    if [ "$resp_code" -eq 0 ]; then
        [ -z "$resp_text" ] && echo "ONLINE" || echo "$resp_text"
    elif [ "$resp_code" -eq 1 ]; then
        echo "OFFLINE"
    elif [ "$resp_code" -eq 124 ]; then
        echo "TIMEOUT ($timeout secs)"
    else
        echo "N/A STATUS"
    fi
    count=$(expr "$count" + 1)
done <<< "$NODES"
