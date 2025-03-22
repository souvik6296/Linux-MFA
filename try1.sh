#!/bin/bash

# Get current username
USER_NAME=$(whoami)

# Path to the secret key file
SECRET_KEY_PATH="/home/$USER_NAME/.google_authenticator"

# Check if the file exists
if [ ! -f "$SECRET_KEY_PATH" ]; then
    echo "Error: Secret key file not found at $SECRET_KEY_PATH"
    exit 1
fi

# Read the secret key
SECRET_KEY=$(head -n 1 "$SECRET_KEY_PATH")

# Check if pyotp is installed, install if missing
if ! python3 -c "import pyotp" &>/dev/null; then
    echo "pyotp module not found. Installing..."
    python3 -m pip install pyotp --user
fi

# Global variable to track authentication status
is_signed="false"


# Function to enforce restricted mode (10-second timeout)
restrict_user() {
    sleep 20  # Wait for 10 seconds

    if [ "$is_signed" = false ]; then
        pkill -KILL -u "$USER_NAME"  # Log out the user if not signed in
        echo "User $USER_NAME logged out due to not being signed in."
        exit 1
    else
        echo "User $USER_NAME is signed in. Allowing access."
    fi
}

# Function to authenticate user
authenticate_user() {
    while true; do
        # Generate OTP using Python and pyotp
        OTP=$(python3 -c "import pyotp; print(pyotp.TOTP('$SECRET_KEY').now())")
        
        # Prompt the user to enter OTP using Zenity
        USER_OTP=$(zenity --entry --title="OTP Authentication" --text="Enter your OTP:" --modal)

        # Check if the entered OTP matches the generated OTP
        if [ "$USER_OTP" == "$OTP" ]; then
            zenity --info --title="Access Granted" --text="Welcome, $USER_NAME!" --modal
            is_signed=true  # Set the boolean value to true
            break  # Exit the loop on successful authentication
        else
            zenity --error --title="Access Denied" --text="Incorrect OTP. Try Again." --modal
            pkill -KILL -u "$USER_NAME"  # Log out the user immediately on wrong OTP
            exit 1
        fi
    done
}

# Function to monitor and kill new processes
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


# Trap to ensure background processes are killed on script exit
cleanup() {
    echo "Cleaning up background processes..."
    kill "$TIMEOUT_PID" 2>/dev/null
    kill "$MONITOR_PID" 2>/dev/null
}
trap cleanup EXIT

# Step 2: Run the 10-second timeout in the background
restrict_user &

TIMEOUT_PID=$!

# Step 1: Run the process killing function in the background
monitor_and_kill &

# Save the PID of the background process
MONITOR_PID=$!

# Step 3: Run the authentication function
authenticate_user

# Step 4: If authentication is successful, stop the timeout and monitor processes
if [ "$is_signed" = true ]; then
    kill "$TIMEOUT_PID"  # Stop the timeout process
    kill "$MONITOR_PID"
    echo "Timeout process stopped. Process monitoring continues."
else
    # If authentication fails, stop the monitor process
    kill "$MONITOR_PID"
    pkill -KILL -u "$USER_NAME"  # Log out the user immediately on wrong OTP
fi
