#!/bin/bash

nososess="nosomine"
nosopath="."
if tmux has-session -t $nososess 2>/dev/null; then
    echo "A tmux session $nososess is running!"
    exit
fi
if [ -n "$(pidof noso-go)" ]; then
    echo "A noso-go process is running!"
    exit
fi
if [ -n "$(pgrep -f ngExec.sh)" ]; then
    echo "A ngExec.sh process is running!"
    exit
fi
if [ -n "$(pgrep -f ngKill.sh)" ]; then
    echo "A ngKill.sh process is running!"
    exit
fi
tmux new -s $nososess -d
tmux split-window -v -t $nososess0.0
tmux split-window -h -t $nososess0.1
tmux send-keys -t $nososess:0.0 "cd $nosopath" C-m
tmux send-keys -t $nososess:0.1 "cd $nosopath" C-m
tmux send-keys -t $nososess:0.2 "cd $nosopath" C-m
tmux send-keys -t $nososess:0.0 './ngExec.sh' C-m
tmux send-keys -t $nososess:0.1 './ngKill.sh' C-m
tmux send-keys -t $nososess:0.2 'sleep 10s; while [ ! -f pooling.log ]; do sleep 10; done; tail -f pooling.log' C-m
echo 'New ngTmux DONE!'
[ "$1" = "a" ] && tmux a -t $nososess
