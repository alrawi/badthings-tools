# Logging
exec 3>&2 # logging stream (file descriptor 3) defaults to STDERR
verbosity=5 # default to show warnings
silent_lvl=0
crt_lvl=1
err_lvl=2
wrn_lvl=3
inf_lvl=4
dbg_lvl=5

notify() { log $silent_lvl "NOTE: $1"; } # Always prints
critical() { log $crt_lvl "CRITICAL: $1"; }
error() { log $err_lvl "ERROR: $1"; }
warn() { log $wrn_lvl "WARNING: $1"; }
inf() { log $inf_lvl "INFO: $1"; } # "info" is already a command
debug() { log $dbg_lvl "DEBUG: $1"; }
log() {
    if [ $verbosity -ge $1 ]; then
        datestring=`date +'%Y-%m-%d %H:%M:%S'`
        # Expand escaped characters, wrap at 70 chars, indent wrapped lines
        echo -e "$datestring $2" | fold -w70 -s | sed '2~1s/^/  /' >&3
    fi
}
