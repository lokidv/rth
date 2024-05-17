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

# Function to fetch server information using ip-api.com
fetch_server_info() {
    local response=$(curl -sS "http://ip-api.com/json/$SERVER_IP")
    if echo "$response" | jq . >/dev/null 2>&1; then
        SERVER_COUNTRY=$(echo "$response" | jq -r '.country')
        SERVER_ISP=$(echo "$response" | jq -r '.isp')
    else
        echo -e "${RED}Failed to fetch server information from ip-api.com${NC}"
        SERVER_COUNTRY="Unknown"
        SERVER_ISP="Unknown"
    fi
}

# Fetch server information
fetch_server_info

# Function to display ASCII logo
display_logo() {
    echo -e "${BLUE}"
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
    # Check if the rathole-core installed or not
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

# Global Variables
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

