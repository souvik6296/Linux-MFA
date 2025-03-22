#!/bin/bash


# Get the current username using whoami
USERNAME=$(whoami)

# Get the directory where this script (setup.sh) is located
SCRIPT_DIR=$(dirname "$(realpath "$0")")


# Navigate to the root directory to ensure consistent paths
cd /


# Function to check if google-authenticator is installed
check_google_authenticator_installed() {
    if dpkg -s google-authenticator &>/dev/null; then
        echo "google-authenticator is already installed."
        return 0
    else
        echo "google-authenticator is not installed."
        return 1
    fi
}

# Function to install google-authenticator
install_google_authenticator() {
    echo "Installing google-authenticator..."
    if sudo apt update && sudo apt install -y google-authenticator; then
        echo "google-authenticator installed successfully."
        return 0
    else
        echo "Failed to install google-authenticator."
        return 1
    fi
}

# Function to run google-authenticator and set up the secret key
setup_google_authenticator() {
    echo "Setting up google-authenticator..."
    echo "Follow the prompts to configure your Google Authenticator:"
    google-authenticator

    # Check if the setup was successful
    if [ $? -eq 0 ]; then
        echo "Google Authenticator setup completed successfully."
    else
        echo "Google Authenticator setup failed. Please try again."
        exit 1
    fi
}

# Function to copy otp_prompt.sh to /home/$USERNAME/
copy_otp_prompt() {
    local source_file="$SCRIPT_DIR/otp_prompt.sh"  # Path to otp_prompt.sh in the same directory as setup.sh
    local destination_file="/home/$USERNAME/otp_prompt.sh"

    # Check if otp_prompt.sh exists in the script directory
    if [ ! -f "$source_file" ]; then
        echo "Error: otp_prompt.sh not found in $SCRIPT_DIR."
        exit 1
    fi

    # Copy otp_prompt.sh to /home/$USERNAME/
    if cp "$source_file" "$destination_file"; then
        echo "Copied otp_prompt.sh to $destination_file."
    else
        echo "Failed to copy otp_prompt.sh to $destination_file."
        exit 1
    fi
}

# Function to change file permissions
change_permissions() {
    local google_auth_file="/home/$USERNAME/.google_authenticator"  # Explicit path using $USERNAME
    local otp_prompt_file="/home/$USERNAME/otp_prompt.sh"          # Explicit path using $USERNAME

    # Change .google-authenticator file permissions to 777
    if chmod 777 "$google_auth_file"; then
        echo "Changed permissions of $google_auth_file to 777."
    else
        echo "Failed to change permissions of $google_auth_file."
        exit 1
    fi

    # Change otp_prompt.sh file permissions to 111
    if chmod 111 "$otp_prompt_file"; then
        echo "Changed permissions of $otp_prompt_file to 111."
    else
        echo "Failed to change permissions of $otp_prompt_file."
        exit 1
    fi
}

# Function to add a file to startup applications
add_to_startup() {
    local file_path="/home/$USERNAME/otp_prompt.sh"  # Explicit path using $USERNAME
    local autostart_dir="/home/$USERNAME/.config/autostart"
    local desktop_file="$autostart_dir/otp_prompt.desktop"

    # Create the autostart directory if it doesn't exist
    mkdir -p "$autostart_dir"

    # Create the desktop entry file
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Exec=$file_path
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=OTP Prompt
Comment=Run OTP Prompt at startup
EOF

    if [ $? -eq 0 ]; then
        echo "Added $file_path to startup applications."
    else
        echo "Failed to add $file_path to startup applications."
        exit 1
    fi
}

# Main script logic
if ! check_google_authenticator_installed; then
    if ! install_google_authenticator; then
        echo "Error: Unable to install google-authenticator. Please check your internet connection or permissions."
        exit 1
    fi
fi

# Run google-authenticator to set up the secret key
setup_google_authenticator

# Copy otp_prompt.sh to /home/$USERNAME/
copy_otp_prompt

# Change file permissions
change_permissions

# Add otp_prompt.sh to startup applications
add_to_startup

echo "Setup complete. Google Authenticator and OTP Prompt are ready to use."
