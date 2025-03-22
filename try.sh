#!/bin/bash

# Function to monitor and kill new processes
monitor_and_kill() {
    # List of system processes to exclude (add more as needed)
    system_processes=("kworker" "ksoftirqd" "migration" "rcu_sched" "watchdog" "i915" "systemd" "dbus-daemon")

    # Get the PID of the current terminal (to avoid killing it)
    current_terminal_pid=$(ps -o ppid= -p $$ | xargs)
    current_terminal_name=$(ps -o comm= -p $current_terminal_pid)

    # Add the current terminal process to the excluded list
    system_processes+=("$current_terminal_name")
    
    
    # Add the authentication process (zenity) to the excluded list
    system_processes+=("zenity")

    # Function to get the list of currently running processes
    get_running_processes() {
        ps -eo pid,comm --no-headers | awk '{print $2}' | sort
    }

    # Get the initial list of running processes (before the script starts monitoring)
    initial_processes=$(get_running_processes)

    # Add excluded processes to the initial list
    initial_processes+=$'\n'"${system_processes[@]}"

    # Main loop to monitor and kill new processes
    while true; do
        # Get the current list of running processes
        current_processes=$(get_running_processes)

        # Find new processes (processes in current_processes but not in initial_processes)
        new_processes=$(comm -13 <(echo "$initial_processes" | sort) <(echo "$current_processes" | sort))

        # Kill new processes (excluding system processes and the current terminal)
        for process in $new_processes; do
            if [[ ! " ${system_processes[@]} " =~ " ${process} " ]]; then
                echo "Detected new process: $process"
                if pkill "$process"; then
                    echo "Killed process: $process"
                else
                    echo "Failed to kill process: $process (Operation not permitted)"
                fi
            fi
        done

        # Wait for a short interval before checking again
        sleep 1
    done
}

# Run the function in the background
monitor_and_kill &

# Save the PID of the background process
BACKGROUND_PID=$!

# Print the background process PID
echo "Monitoring and killing new processes in the background. PID: $BACKGROUND_PID"

# Trap Ctrl+C (SIGINT) to stop the background process
trap "echo 'Stopping background process...'; kill $BACKGROUND_PID; exit" INT

# Allow the user to continue using the terminal
echo "You can now use this terminal for other tasks."
echo "Press Ctrl+C to stop the background process."

# Wait indefinitely (to keep the script running)
wait
