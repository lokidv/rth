#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   sleep 1
   exit 1
fi

# Function to install unzip if not already installed
install_unzip() {
    if ! command -v unzip &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}unzip is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y unzip
        else
            echo -e "${RED}Error: Unsupported package manager. Please install unzip manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    
    else
        echo -e "${GREEN}unzip is already installed.${NC}"
    fi
}

# Install unzip
install_unzip

# Function to install jq if not already installed
install_jq() {
    if ! command -v jq &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${RED}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    
    else
        echo -e "${GREEN}jq is already installed.${NC}"
    
    fi
    
}

# Install jq
install_jq

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Fetch server country using ip-api.com
SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')

# Fetch server isp using ip-api.com 
SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')

# Function to display ASCII logo
display_logo() {
    echo -e "${BLUE}"
    cat << "EOF"
 ____      _  _____ _   _  ___  _     _____ 
|  _ \    / \|_   _| | | |/ _ \| |   | ____|
| |_) |  / _ \ | | | |_| | | | | |   |  _|  
|  _ <  / ___ \| | |  _  | |_| | |___| |___ 
|_| \_\/_/   \_\_| |_| |_|\___/|_____|_____|  
                  By github.com/Musixal v1.1                       
EOF
    echo -e "${NC}"
}

# Function to display server location and IP
display_server_info() {
    echo -e "${GREEN}Server Country:${NC} $SERVER_COUNTRY"
    echo -e "${GREEN}Server IP:${NC} $SERVER_IP"
    echo -e "${GREEN}Server ISP:${NC} $SERVER_ISP"
}

# Function to display Rathole Core installation status
display_rathole_core_status() {
    if [[ -d "$config_dir" ]]; then
        echo -e "${GREEN}Rathole Core installed.${NC}"
    else
        echo -e "${RED}Rathole Core not installed.${NC}"
    fi
}


# Function for configuring tunnel
configure_tunnel() {

# check if the rathole-core installed or not
if [[ ! -d "$config_dir" ]]; then
    echo -e "\n${RED}Rathole-core directory not found. Install it first through option 4.${NC}\n"
    read -p "Press Enter to continue..."
    return 1
fi

    clear
    echo -e "${YELLOW}Configurating RatHole Tunnel...${NC}\n"
    echo -e "1. For ${GREEN}IRAN${NC} Server\n"
    echo -e "2. For ${BLUE}Kharej${NC} Server\n"
    read -p "Enter your choice: " configure_choice
    case "$configure_choice" in
        1) iran_server_configuration ;;
        2) kharej_server_configuration ;;
        *) echo -e "${RED}Invalid option!${NC}" && sleep 1 ;;
    esac
    echo ''
    read -p "Press Enter to continue..."
}


#Global Variables
     config_dir="/root/rathole-core"
     iran_config_file="${config_dir}/server.toml"
     iran_service_name="rathole-iran.service"
     iran_service_file="/etc/systemd/system/${iran_service_name}"

    kharej_config_file="${config_dir}/client.toml"
    kharej_service_name="rathole-kharej.service"
    kharej_service_file="/etc/systemd/system/${kharej_service_name}"
    
# Function to configure Iran server
iran_server_configuration() {  
    clear
    echo -e "${YELLOW}Configuring IRAN server...${NC}\n" 
    
    # Read the tunnel port
    read -p "Enter the tunnel port: " tunnel_port
    while ! [[ "$tunnel_port" =~ ^[0-9]+$ ]]; do
        echo -e "${RED}Please enter a valid port number.${NC}"
        read -p "Enter the tunnel port: " tunnel_port
    done
    
    echo ''
    # Read the number of config ports and read each port
    read -p "Enter the number of your configs: " num_ports
    while ! [[ "$num_ports" =~ ^[0-9]+$ ]]; do
        echo -e "${RED}Please enter a valid number.${NC}"
        read -p "Enter the number of your configs: " num_ports
    done
    
    echo ''
    config_ports=()
    for ((i=1; i<=$num_ports; i++)); do
        read -p "Enter Config Port $i: " port
        while ! [[ "$port" =~ ^[0-9]+$ ]]; do
            echo -e "${RED}Please enter a valid port number.${NC}"
            read -p "Enter Config Port $i: " port
        done
        config_ports+=("$port")
    done

echo ''

# Initialize transport variable
local transport=""

# Keep prompting the user until a valid input is provided
while [[ "$transport" != "tcp" && "$transport" != "udp" ]]; do
    # Prompt the user to input transport type
    read -p "Enter transport type (tcp/udp): " transport

    # Check if the input is either tcp or udp
    if [[ "$transport" != "tcp" && "$transport" != "udp" ]]; then
        echo -e "${RED}Invalid transport type. Please enter 'tcp' or 'udp'.${NC}"
    fi
done

    # Generate server configuration file
    cat << EOF > "$iran_config_file"
[server]
bind_addr = "0.0.0.0:${tunnel_port}"
default_token = "musixal_tunnel"
heartbeat_interval = 30

[server.transport]
type = "tcp"

EOF

    # Add each config port to the configuration file
    for port in "${config_ports[@]}"; do
        cat << EOF >> "$iran_config_file"
[server.services.${port}]
type = "$transport"
bind_addr = "0.0.0.0:${port}"

EOF
    done
    
    echo ''
    echo -e "${GREEN}IRAN server configuration completed.${NC}\n"
    echo -e "Starting Rathole server as a service...\n"

    # Create the systemd service unit file
    cat << EOF > "$iran_service_file"
[Unit]
Description=Rathole Server (Iran)
After=network.target

[Service]
Type=simple
ExecStart=${config_dir}/rathole ${iran_config_file}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to read the new unit file
    if systemctl daemon-reload; then
        echo "Systemd daemon reloaded."
    else
        echo -e "${RED}Failed to reload systemd daemon. Please check your system configuration.${NC}"
        return 1
    fi

    # Enable the service to start on boot
    if systemctl enable "$iran_service_name"; then
        echo -e "${GREEN}Service '$iran_service_name' enabled to start on boot.${NC}"
    else
        echo -e "${RED}Failed to enable service '$iran_service_name'. Please check your system configuration.${NC}"
        return 1
    fi

    # Start the service
    if systemctl start "$iran_service_name"; then
        echo -e "${GREEN}Service '$iran_service_name' started.${NC}"
    else
        echo -e "${RED}Failed to start service '$service_name'. Please check your system configuration.${NC}"
        return 1
    fi
}

# Function for configuring Kharej server
kharej_server_configuration() {
    clear
    echo -e "${YELLOW}Configuring kharej server...${NC}\n"
    
    # Read the server address
    read -p "Enter the IRAN server address: " SERVER_ADDR

    echo ''
    # Read the tunnel port
    read -p "Enter the tunnel port: " tunnel_port
    while ! [[ "$tunnel_port" =~ ^[0-9]+$ ]]; do
        echo -e "${RED}Please enter a valid port number.${NC}"
        read -p "Enter the tunnel port: " tunnel_port
    done
    
    echo ''
    # Read the number of config ports and read each port
    read -p "Enter the number of your configs: " num_ports
    while ! [[ "$num_ports" =~ ^[0-9]+$ ]]; do
        echo -e "${RED}Please enter a valid number.${NC}"
        read -p "Enter the number of your configs: " num_ports
    done
    
    echo ''
    config_ports=()
    for ((i=1; i<=$num_ports; i++)); do
        read -p "Enter Config Port $i: " port
        while ! [[ "$port" =~ ^[0-9]+$ ]]; do
            echo -e "${RED}Please enter a valid port number.${NC}"
            read -p "Enter Config Port $i: " port
        done
        config_ports+=("$port")
    done

echo ''
# Initialize transport variable
local transport=""

# Keep prompting the user until a valid input is provided
while [[ "$transport" != "tcp" && "$transport" != "udp" ]]; do
    # Prompt the user to input transport type
    read -p "Enter transport type (tcp/udp): " transport

    # Check if the input is either tcp or udp
    if [[ "$transport" != "tcp" && "$transport" != "udp" ]]; then
        echo -e "${RED}Invalid transport type. Please enter 'tcp' or 'udp'.${NC}"
    fi
done


    # Generate server configuration file
    cat << EOF > "$kharej_config_file"
[client]
remote_addr = "${SERVER_ADDR}:${tunnel_port}"
default_token = "musixal_tunnel"
heartbeat_timeout = 40
retry_interval = 1

[client.transport]
type = "tcp"

EOF

    # Add each config port to the configuration file
    for port in "${config_ports[@]}"; do
        cat << EOF >> "$kharej_config_file"
[client.services.${port}]
type = "$transport"
local_addr = "0.0.0.0:${port}"

EOF
    done

    echo ''
    echo -e "${GREEN}Kharej server configuration completed.${NC}\n"
    echo -e "${GREEN}Starting Rathole server as a service...${NC}\n"

    # Create the systemd service unit file
    cat << EOF > "$kharej_service_file"
[Unit]
Description=Rathole Server (Kharej)
After=network.target

[Service]
Type=simple
ExecStart=${config_dir}/rathole ${kharej_config_file}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to read the new unit file
    if systemctl daemon-reload; then
        echo "Systemd daemon reloaded."
    else
        echo -e "${RED}Failed to reload systemd daemon. Please check your system configuration.${NC}"
        return 1
    fi

    # Enable the service to start on boot
    if systemctl enable "$kharej_service_name"; then
        echo -e "${GREEN}Service '$kharej_service_name' enabled to start on boot.${NC}"
    else
        echo -e "${RED}Failed to enable service '$kharej_service_name'. Please check your system configuration.${NC}"
        return 1
    fi

    # Start the service
    if systemctl start "$kharej_service_name"; then
        echo -e "${GREEN}Service '$kharej_service_name' started.${NC}"
    else
        echo -e "${RED}Failed to start service '$kharej_service_name'. Please check your system configuration.${NC}"
        return 1
    fi

}

# Function for destroying tunnel
destroy_tunnel() {
    echo ''
    echo -e "${YELLOW}Destroying tunnel...${NC}\n"
    sleep 1
    
    # Prompt to confirm before removing Rathole-core directory
    read -p "Are you sure you want to remove Rathole-core? (y/n): " confirm
    echo ''
if [[ $confirm == [yY] ]]; then
    if [[ -d "$config_dir" ]]; then
        rm -rf "$config_dir"
        echo -e "${GREEN}Rathole-core directory removed.${NC}\n"
    else
        echo -e "${RED}Rathole-core directory not found.${NC}\n"
    fi
else
    echo -e "${YELLOW}Removal canceled.${NC}\n"
fi


    # remove cronjob created by thi script
    delete_cron_job 
    echo ''
    # Stop and disable the client service if it exists
    if [[ -f "$kharej_service_file" ]]; then
        if systemctl is-active "$kharej_service_name" &>/dev/null; then
            systemctl stop "$kharej_service_name"
            systemctl disable "$kharej_service_name"
        fi
        rm -f "$kharej_service_file"
    fi


    # Stop and disable the Iran server service if it exists
    if [[ -f "$iran_service_file" ]]; then
        if systemctl is-active "$iran_service_name" &>/dev/null; then
            systemctl stop "$iran_service_name"
            systemctl disable "$iran_service_name"
        fi
        rm -f "$iran_service_file"
    fi

    # Reload systemd to read the new unit file
    if systemctl daemon-reload; then
        echo -e "Systemd daemon reloaded.\n"
    else
        echo -e "${RED}Failed to reload systemd daemon. Please check your system configuration.${NC}"
    fi
    
    echo -e "${GREEN}Tunnel destroyed successfully!${NC}\n"
    read -p "Press Enter to continue..."
}


# Function for checking tunnel status
check_tunnel_status() {
    echo ''
    echo -e "${YELLOW}Checking tunnel status...${NC}\n"
    sleep 1
    
    # Check if the rathole-client-kharej service is active
    if systemctl is-active --quiet "$kharej_service_name"; then
        echo -e "${GREEN}Kharej service is running on this server.${NC}"
    else
        echo -e "${RED}Kharej service is not running on this server.${NC}"
    fi
    
    echo ''
    # Check if the rathole-server-iran service is active
    if systemctl is-active --quiet "$iran_service_name"; then
        echo -e "${GREEN}IRAN service is running on this server..${NC}"
    else
        echo -e "${RED}IRAN service is not running on this server..${NC}"
    fi
    echo ''
    read -p "Press Enter to continue..."
}

#Function to restart services
restart_services() {
    echo ''
    echo -e "${YELLOW}Restarting IRAN & Kharej services...${NC}\n"
    sleep 1
    # Check if rathole-client-kharej.service exists
    if systemctl list-units --type=service | grep -q "$kharej_service_name"; then
        systemctl restart "$kharej_service_name"
        echo -e "${GREEN}Kharej service restarted.${NC}"
    fi

    # Check if rathole-server-iran.service exists
    if systemctl list-units --type=service | grep -q "$iran_service_name"; then
        systemctl restart "$iran_service_name"
        echo -e "${GREEN}IRAN service restarted.${NC}"
    fi

    # If neither service exists
    if ! systemctl list-units --type=service | grep -q "$kharej_service_name" && \
       ! systemctl list-units --type=service | grep -q "$iran_service_name"; then
        echo -e "${RED}There is no service to restart.${NC}"
    fi
    
     echo ''
     read -p "Press Enter to continue..."
}

# Function to add cron-tab job
add_cron_job() {
    local reset_path=$1
    local restart_time=$2

    # Save existing crontab to a temporary file
    crontab -l > /tmp/crontab.tmp

    # Append the new cron job to the temporary file
    echo "$restart_time $reset_path # Added by rathole_script" >> /tmp/crontab.tmp

    # Install the modified crontab from the temporary file
    crontab /tmp/crontab.tmp

    # Remove the temporary file
    rm /tmp/crontab.tmp
}
delete_cron_job() {
    # Delete all cron jobs added by this script
    crontab -l | grep -v '# Added by rathole_script' | crontab -
    rm -f /etc/reset.sh >/dev/null 2>&1
    echo -e "${GREEN}Cron jobs added by this script have been deleted successfully.${NC}"
}


# Main function to add or delete cron job for restarting services
cronjob_main() {
     clear
     # Prompt user for action
    echo -e "Select an option: \n"
    echo -e "${BLUE}1. Add a cron-job to restart a service${NC}\n"
    echo -e "${RED}2. Delete cron jobs added by this script${NC}\n"
    read -p "Enter your choice: " action_choice
    echo ''
    # Validate user input
    case $action_choice in
        1)
            add_cron_job_menu
            ;;
        2)
            delete_cron_job
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}"
            return 1
            ;;
    esac
    echo ''
    read -p "Press Enter to continue..."
}

add_cron_job_menu() {
    clear
    # Prompt user to choose a service
    echo -e "Select the service you want to restart:\n"
    echo -e "${BLUE}1. Kharej service${NC}"
    echo -e "${GREEN}2. IRAN service${NC}"
    echo ''
    read -p "Enter your choice: " service_choice
    echo ''
    # Validate user input
    case $service_choice in
        1)
            service_name="$kharej_service_name"
            ;;
        2)
            service_name="$iran_service_name"
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}"
            return 1
            ;;
    esac

    # Prompt user to choose a restart time interval
    echo "Select the restart time interval:"
    echo ''
    echo "1. Every 1 hour"
    echo "2. Every 2 hours"
    echo "3. Every 4 hours"
    echo "4. Every 6 hours"
    echo "5. Every 12 hours"
    echo "6. Every 24 hours"
    echo ''
    read -p "Enter your choice: " time_choice
    echo ''
    # Validate user input for restart time interval
    case $time_choice in
        1)
            restart_time="0 * * * *"
            ;;
        2)
            restart_time="0 */2 * * *"
            ;;
        3)
            restart_time="0 */4 * * *"
            ;;
        4)
            restart_time="0 */6 * * *"
            ;;
        5)
            restart_time="0 */12 * * *"
            ;;
        6)
            restart_time="0 0 * * *"
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a number between 1 and 6.${NC}\n"
            return 1
            ;;
    esac


    # remove cronjob created by thi script
    delete_cron_job > /dev/null 2>&1
    
    # Path ro reset file
    reset_path='/etc/reset.sh'
    
    #add cron job to kill the running rathole processes
    cat << EOF > "$reset_path"
#! /bin/bash
pids=\$(pgrep rathole)
sudo kill -9 $pids
sudo systemctl daemon-reload
sudo systemctl restart $service_name
EOF

    # make it +x !
    chmod +x "$reset_path"
    
    # Add cron job to restart the specified service at the chosen time
    add_cron_job "$reset_path" "$restart_time"

    echo -e "${GREEN}Cron-job added successfully to restart the service '$service_name'.${NC}"
}

# Function to download and extract Rathole Core
download_and_extract_rathole() {
    echo ''
    # check if core installed already
    if [[ -d "$config_dir" ]]; then
        echo -e "${GREEN}Rathole Core is already installed.${NC}"
        echo ''
        read -p "Press Enter to continue..."
        return 1
    fi
    
    # Check operating system
    if [[ $(uname) == "Linux" ]]; then
        ARCH=$(uname -m)
        DOWNLOAD_URL=$(curl -sSL https://api.github.com/repos/rapiz1/rathole/releases/latest | grep -o "https://.*$ARCH.*linux.*zip" | head -n 1)
    else
        echo -e "${RED}Unsupported operating system.${NC}"
        sleep 1
        exit 1
    fi

    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}Failed to retrieve download URL.${NC}"
        sleep 1
        exit 1
    fi

    DOWNLOAD_DIR=$(mktemp -d)
    echo -e "Downloading Rathole from $DOWNLOAD_URL...\n"
    sleep 1
    curl -sSL -o "$DOWNLOAD_DIR/rathole.zip" "$DOWNLOAD_URL"
    echo -e "Extracting Rathole...\n"
    sleep 1
    unzip -q "$DOWNLOAD_DIR/rathole.zip" -d "$config_dir"
    echo -e "${GREEN}Rathole installation completed.${NC}\n"
    rm -rf "$DOWNLOAD_DIR"
    read -p "Press Enter to continue..."
}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display menu
display_menu() {
    clear
    display_logo
    display_server_info
    echo "-------------------------------"
    display_rathole_core_status
    echo "-------------------------------"
    echo ''
    echo -e "${GREEN}1. Configure tunnel${NC}"
    echo -e "${RED}2. Destroy tunnel${NC}"
    echo -e "${BLUE}3. Check tunnel status${NC}"
    echo -e "4. Install Rathole Core"
    echo -e "${YELLOW}5. Restart services${NC}"
    echo -e "6. Add & remove cron-job reset timer"
    echo -e "7. Exit"
    echo ''
    echo "-------------------------------"
}

# Function to read user input
read_option() {
    read -p "Enter your choice: " choice
    case $choice in
        1) configure_tunnel ;;
        2) destroy_tunnel ;;
        3) check_tunnel_status ;;
        4) download_and_extract_rathole ;;
        5) restart_services ;;
        6) cronjob_main ;;
        7) exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}" && sleep 1 ;;
    esac
}

# Main script
while true
do
    display_menu
    read_option
done
