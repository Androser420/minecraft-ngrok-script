# minecraft-ngrok-script
A simple bash script that starts and monitors both your minecraft server and ngrok using tmux sessions and a Discord webhook for server status &amp; IP.

## Requirements:
Packages:
- jq
- tmux
- curl
- ngrok

Things that need to be set up and configured:
- ngrok
- your server startup shell file

Only Linux is supported for now (maybe MacOS, not tested)

# Tips for WSL2
- if you run into the "./run.sh: cannot execute: required file not found" error, install dos2unix and convert both of the scripts.
