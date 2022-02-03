# NosoStuff
Some handy scripts facilitate noso cryptocurrency mining, masternode running, ...

## FOR MINING USING `noso-go`

### Why I (and you?) need these scripts
Crypto mining is always unstable by many reasons, like the network communication, the softwares themself, ...
That is unavoidable in case of  [Noso Cryptocurrency](https://nosocoin.com), mining on pools ([NosoWallet](https://github.com/Noso-Project/NosoWallet) up to version `v0.2.1Lb1`) using the admirable miner [noso-go](https://github.com/Noso-Project/noso-go) (up to version `v1.6.2`).
`Watchdog triggered`, `POOLFULL`, `BANNED`, `ALREADYCONNECTED`, `PING 0`, or pool offline ...
These kind of dead events may appear at any time and cause my mining stop while my computers continue running and consuming the electricity until I have time to check and restart the miners

I need tools to:
    - Automatically stop the mining in case of dead events appear.
    - Automatically restart mining or switch to another pool and/or wallet address to continue the mining.

And, here they are! `ngExec.sh`, `ngKill.sh`, `ngTmuxNew.sh`, `ngTmuxEnd.sh` (bash shell scripts)

![Screenshot](images/ngTools.png)

### Supported OSs/ Platforms:
Linux, Android(Termux), and macOS. Currently not support Windows

### Required packages: `tmux`, `nc` (`netcat`), `timeout`, `sed`, `grep`, `pgrep`

*** In Linux: Most of these packages are common and installed by default in linux distros

*** In macOS: the `nc` Apple version is bugful, use the brew version instead
    - `brew install tmux netcat`

*** In Android/Termux:
    - `pkg update && pkg upgrade && pkg install termux netcat-openbsd`

### Quick runing
- Put all relating files in the same folder (ex.: `NosoStuff`) with the `noso-go`
- Set parameters (descripted below)
- Open terminal, go to folder `NosoStuff`
- Set executable permission to script files:
    `chmod +x ngTmuxNew.sh`
    `chmod +x ngTmuxEnd.sh`
    `chmod +x ngExec.sh`
    `chmod +x ngKill.sh`
- Run appropriate commands bellow from shell prompt ($, #, ...):
    `./ngTmuxNew.sh`    # for launching the mining processes
    `./ngTmuxEnd.sh`    # for turning off the mining processes
- To view the `tmux` session (with mining processes run in) by command:
    `tmux a -tnosomine`
- To close the above `tmux` screen (and let mining processes run) by keystrokes:
    `Ctr-b d`

### Set parameters:
In file ngExec.sh:
- `CPU`: The number of CPUs the noso-go uses for mining
- `POOLS`: List of pools can be used. 
- `USERS`: List of users (wallet addresses/ aliases) can be used
- `SWITCH_DURATION`: Duration in seconds the noso-go does mining in case the selected pool and/or user are not preferred. After this duration, noso-go will try back to mine using the preferred pool and user (the 1st one in POOLS and USERS lists)

In file ngKill.sh:
- `TIME_CYCLE`: Duration in seconds periodically (default 5 secs) the noso-go log file be scanned to detect the dead events.

*** POOLS and USERS can also be set in the corresponding files pools.txt and users.txt in the same formation as they are in file ngExec.sh.

*** Other parameters can be found in the script files

### How they work

- The `ngExec.sh`: Everytime the miner `noso-go` to be terminated, the `ngExec.sh` do scan the latest lines of `noso-go` log file to find the reason; then tries to select an approriate pool, and/or user; and then restart the miner with those parameters.

- The `ngKill.sh`: peridically 5 seconds (configurable), `ngKill.sh` does scan the latest lines of `noso-go` log file to detect if an dead event appear, and then force killing that sick miner. That gives a chance to the miner to be restarted by the `ngExec.sh` with approriate pool and/or user.

- The combination of both `ngExec.sh` and `ngKill.sh` in parallel is the way staying with dead events during mining, automatically.

- The `ngTmuxNew.sh` and `ngTmuxEnd.sh` utilize for launching and turning off both `ngExec.sh` and `ngKill.sh` at once on a single `tmux` session.
