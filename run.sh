#!/bin/bash

clear ; echo $'WARNING: This script will only work if you have already set up your server and ngrok as this script\'s purpose is to make your life easier by automating processes like starting the server and ngrok in tmux sessions.\nThis script is not made for Windows and it won\'t work unless you run your server from WSL2, chroot, a VM or almost any native Linux distribution.\n\nAlso remember that when entering your server files\' location, you must provide a full path without backslashes.\nIf you\'re willing to modify the given values, the configuration file is stored within this script\'s directory.\n\nTo stop the server including this script and ngrok, all you have to do send a /stop minecraft command and you\'re done!\n\nEnjoy!\n - Androser\n'

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to prompt for information and save it to the configuration file
prompt_and_save_config() {
    read -p "Enter Discord webhook URL: " DISCORD_WEBHOOK_URL
    read -p "Enter server files directory path (e.g. \"/home/user/minecraft server\"): " SERVER_FILES_DIR
    read -p "Enter the name of the shell file that starts the server (e.g., start_server.sh): " START_SCRIPT_NAME
    echo "NOTE: The server jar file will be defined from your current startup script."

    # Find the jar file name in the script content by looking for the .jar extension
    JAR_FILE_NAME=$(grep -oP '\K[^ ]+\.jar' "$SERVER_FILES_DIR/$START_SCRIPT_NAME")

    # Check if a role ping should be included
    read -p "Do you want to ping a role when a crash occurs? (y/n): " INCLUDE_ROLE_PING
    if [ "$INCLUDE_ROLE_PING" = "y" ]; then
        read -p "Enter the numerical ID of the Discord role: " DISCORD_ROLE_ID
        ROLE_PING="<@&$DISCORD_ROLE_ID>"
    else
        ROLE_PING=""
    fi

    # Save configuration to the file
    echo "DISCORD_WEBHOOK_URL='$DISCORD_WEBHOOK_URL'" > "$SCRIPT_DIR/script.conf"
    echo "SERVER_FILES_DIR='$SERVER_FILES_DIR'" >> "$SCRIPT_DIR/script.conf"
    echo "START_SCRIPT_NAME='$START_SCRIPT_NAME'" >> "$SCRIPT_DIR/script.conf"
    echo "JAR_FILE_NAME='$JAR_FILE_NAME'" >> "$SCRIPT_DIR/script.conf"
    echo "ROLE_PING='$ROLE_PING'" >> "$SCRIPT_DIR/script.conf"
}

# Check if the configuration file exists
if [ -f "$SCRIPT_DIR/script.conf" ]; then
    # Read configuration from the file
    source "$SCRIPT_DIR/script.conf"
else
    # If the file doesn't exist, create it by prompting for information
    prompt_and_save_config
fi

# Function to send ngrok IP to a Discord webhook
send_ngrok_ip_to_discord() {
    ngrok_url=$(curl -s localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
    if [ -n "$ngrok_url" ]; then
        ngrok_ip=$(echo "$ngrok_url" | sed 's|tcp://||')
        curl -H "Content-Type: application/json" -X POST -d "$(jq -n --arg content $'## :green_circle: Server is up! :green_circle:\n- _Temporary IP:_\n```\n'$ngrok_ip'```' '{"content":$content}')" $DISCORD_WEBHOOK_URL
        echo "Ngrok IP sent to Discord: $ngrok_ip"
    else
        echo "Failed to retrieve Ngrok URL."
    fi
}

# Function to check for crash report in the logs
LOG_FILE="$SERVER_FILES_DIR/logs/latest.log"

check_crash_report() {
    if grep -q -i "Preparing crash report" "$LOG_FILE"; then
        echo "fail"
    elif grep -q -i "Failed to initialize server" "$LOG_FILE"; then
        echo "fail"
    else
        echo "success"
    fi
}

# Set the shell to Bash explicitly because it loads faster than zsh or fish (also cuz of OMZ/F rice)
SHELL=/bin/bash

# Create a new tmux session for the Minecraft server
tmux new-session -d -s minecraft_tmux -n server_console

# Change directory to the server files directory
tmux send-keys "cd \"$SERVER_FILES_DIR\"" C-m

# Run the Minecraft server in the first tmux window
tmux send-keys "./$START_SCRIPT_NAME" C-m

# Detach from the Minecraft tmux session
tmux detach

# Create a new tmux session for Ngrok
tmux new-session -d -s ngrok_session -n ngrok_window

tmux send-keys "ngrok tcp 25565" C-m

tmux detach

# Wait for some time to allow ngrok to establish a tunnel
sleep 10

# Send ngrok URL to the Discord webhook
send_ngrok_ip_to_discord

# Loop check whether the server is running or not
while true; do
    if pgrep -f "$JAR_FILE_NAME" > /dev/null; then
        # echo "Minecraft server is already running."
        sleep 1
    else
        # Check for crash report
        result=$(check_crash_report)
        if [ "$result" = "fail" ]; then
            echo "Minecraft server has crashed!"
            curl -H "Content-Type: application/json" -X POST -d "$(jq -n --arg content $'## :warning: __Server crashed!__ '$ROLE_PING' :warning:' '{"content":$content}')" $DISCORD_WEBHOOK_URL
            pkill -f "ngrok"
            tmux kill-session -t ngrok_session && echo "Successfully stopped ngrok." || echo "Stopping ngrok failed."
        elif [ "$result" = "success" ]; then
            echo "Minecraft server shut down normally."
            curl -H "Content-Type: application/json" -X POST -d "$(jq -n --arg content $'## :red_circle: Server shut down. :red_circle:' '{"content":$content}')" $DISCORD_WEBHOOK_URL
            tmux send-keys -t minecraft_tmux "exit" C-m
            pkill -f "ngrok"
            tmux kill-session -t ngrok_session && echo "Successfully stopped ngrok." || echo "Stopping ngrok failed."
        fi

        # Exit the loop
        break
    fi
    sleep 1

  done &
disown
