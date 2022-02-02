#!/bin/bash

nososess="nosomine"
tmux send-keys -t $nososess:0.0 C-c 2>/dev/null
tmux send-keys -t $nososess:0.1 C-c 2>/dev/null
tmux send-keys -t $nososess:0.2 C-c 2>/dev/null
kill $(pgrep -f ngExec.sh) 2>/dev/null
kill $(pgrep -f ngKill.sh) 2>/dev/null
kill $(pidof noso-go) 2>/dev/null
tmux kill-session -t $nososess 2>/dev/null
echo 'End ngTmux DONE!'
