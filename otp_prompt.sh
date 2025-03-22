#!/bin/bash

# Path to the secret key file
SECRET_KEY_PATH="/home/souvik/.google_authenticator"

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
    pip install pyotp --user
fi

# Get current username
USER_NAME=$(whoami)

# Function to enforce restricted mode
restrict_user() {
    while [ ! -f "/tmp/user_authenticated_$USER_NAME" ]; do
        sleep 10
        if [ ! -f "/tmp/user_authenticated_$USER_NAME" ]; then
            pkill -KILL -u "$USER_NAME"  # Log out the user only if not authenticated
        fi
    done
    exit 0
}

# Function to authenticate user
authenticate_user() {
    while true; do
        OTP=$(python3 -c "import pyotp; print(pyotp.TOTP('$SECRET_KEY').now())")
        USER_OTP=$(zenity --entry --title="OTP Authentication" --text="Enter your OTP:" --modal)

        if [ "$USER_OTP" == "$OTP" ]; then
            zenity --info --title="Access Granted" --text="Welcome, $USER_NAME!" --modal
            touch /tmp/user_authenticated_$USER_NAME
            break
        else
            zenity --error --title="Access Denied" --text="Incorrect OTP. Try Again." --modal
            pkill -KILL -u "$USER_NAME"  # Log out the user immediately on wrong OTP
        fi
    done
}

# Start restricted mode enforcement in the background
restrict_user &
RESTRICT_PID=$!

# Start authentication
authenticate_user

# Kill the restricted mode enforcement once authenticated
kill $RESTRICT_PID
exit 0
