#!/bin/bash

# A simple minecraft server restart script
# with server input and control
# Author: ilightwas <ilightwas@gmail.com>

# debug
# set -x

cmdline="java -Xmx1024M -Xms1024M -jar server.jar nogui"

# in hours, after starting
restart_interval=6

# keep console colored output
keep_output_color=1

# offset the next restart (server load time), in seconds
map_load_wait_offset=120

fifo=".serverin"
pidfile=".serverpid"
run_file=".run"
serverpid=0
empty_line=$(echo -e "\n")

rm_files() {
    echo "Removing control files.."
    [ -e "$fifo" ] && rm -v "$fifo"
    [ -e "$pidfile" ] && rm -v "$pidfile"
    [ -e "$run_file" ] && rm -v "$run_file"
}

should_quit() {
    return $(cat "$run_file")
}

is_server_running() {
    ps -p $(cat "$pidfile") >/dev/null 2>&1
    return "$?"
}

cleanup_sleep() {
    sleep_pid=$(ps | grep sleep | awk "{ print \$1 }")
    [ -n "$sleep_pid" ] && kill "$sleep_pid"
}

try_send_cmd() {
    if ps -p "$1" >/dev/null 2>&1; then
        echo "$2" >"$fifo"
        sleep "$3"
    else
        return 1
    fi
}

queue_restart() {
    sleep $((60 * 60 * restart_interval - 360))
    try_send_cmd "$1" "say Server restart in 5 minutes" 300 &&
        try_send_cmd "$1" "say Server restart in 1 minute" 50 &&
        try_send_cmd "$1" "say Server restarting" 10 &&
        try_send_cmd "$1" "stop" 1 || echo "Server not running, restart cmds aborted.."
}

start_server() {
    while :; do
        echo "Reading pipe input.." >&3
        cat "$fifo"
        sleep 1

        if ! is_server_running; then
            echo "Closing reading loop.." >&3
            break
        fi

    done | eval "$cmdline" &

    serverpid=$!
    echo "$serverpid" >"$pidfile"
    echo "Server pid: $serverpid"

    sleep "$map_load_wait_offset"
    queue_restart "$serverpid" &

    tail --pid="$serverpid" -f /dev/null

    echo "Server process finished.."
    cleanup_sleep

    sleep 1
    echo >"$fifo" # let cat quit

    # wrong: gets script pid
    #done > >($cmdline) &

    # break reading loop
    # done > >($cmdline & echo "$!" > "$pidfile"; wait) &

    # works okish
    # done | $cmdline &

}

manage_server() {
    while :; do
        serverpid=$(cat "$pidfile")
        if ! ps -p "$serverpid" >/dev/null 2>&1; then
            echo "Starting server.."
            start_server
        else
            echo "Server is running.."
        fi

        sleep 1
        if should_quit; then
            break
        fi
    done
}

[ -n "$1" ] && cmdline="$1" && echo "set custom cmdline: $cmdline"

if [ "$keep_output_color" -eq 1 ]; then
    cmdline="script --flush --quiet --return --echo=never /dev/null --command '$cmdline'"
    echo "Keeping colors for cmd: $cmdline"
fi

if [ ! -p "$fifo" ]; then
    [ -e "$fifo" ] && rm "$fifo"
    echo "Creating pipe file $fifo"
    mkfifo "$fifo"
fi

# copy stdout
exec 3>&1

echo 0 >"$pidfile"
echo 1 >"$run_file"

manage_server &
manager_pid=$!

while IFS= read -r line; do
    if [ "$line" = "q" ]; then
        echo "Quitting.."
        echo "stop" >"$fifo"
        echo 0 >"$run_file"
        break
    else
        if [ "$line" = "$empty_line" ]; then
            echo "Got empty input skipping.."
            continue
        fi
    fi
    echo "$line" >"$fifo"
done

tail --pid="$manager_pid" -f /dev/null
rm_files
wait
