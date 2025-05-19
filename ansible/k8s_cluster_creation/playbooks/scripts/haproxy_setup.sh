#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# //////////////////////////////////////////////////////////
#                     HAProxy Setup                        /
# //////////////////////////////////////////////////////////

# EXAMPLE OF INPUT STRING ARGUMENT
# {
#     "ssl": {
#         "enabled": "true",
#         "dns_or_ip": "dns",
#         "dns": "k8s-cluster-dev.mydomain.com",
#         "dns_provider": "digital_ocean"    
#     },
#     "haproxy": {
#         "hostname": "haproxy-2-1",
#         "lan_interface": "eth0",
#         "ip": "192.168.3.14",
#         "state": "MASTER",
#         "router_id": "104",
#         "priority": "100",
#         "password": "clwioji34hui3hiu3hiu",
#         "vip":"192.168.3.50"
#     },
#     "master_nodes": [
#         {
#             "hostname": "k8s-master-node-1-1-srv1",
#             "ip": "192.168.3.11"
#         },
#         {
#             "hostname": "k8s-master-node-2-1-srv1",
#             "ip": "192.168.3.12"
#         }
#     ]
# }

############################################
#               FUNCTIONS                  #
############################################

# Function to install Certbot
install_certbot() {
    #sudo apt-get update
    sudo apt-get install software-properties-common -y
    #sudo add-apt-repository ppa:certbot/certbot -y
    #sudo apt-get update
    sudo apt-get install certbot -y
}

# Function to obtain a certificate
obtain_certificate() {
    local domain=$1
    local dns_provider_name=$2

    # Check if DNS provider is DigitalOcean
    if [ "$dns_provider_name" = "digital_ocean" ]; then
        # Path to DigitalOcean credentials file
        local credentials_path="/etc/letsencrypt/digitalocean/credentials.ini"
        
        # Ensure the credentials file exists
        if [ ! -f "$credentials_path" ]; then
            echo "[ERROR] DigitalOcean credentials file not found at '$credentials_path'"
            return 1
        fi

        # Run Certbot with the DNS DigitalOcean plugin
        sudo certbot certonly \
            --dns-digitalocean \
            --dns-digitalocean-credentials "$credentials_path" \
            -d "$domain" -d "www.$domain" \
            --email "admin@$domain" \
            --agree-tos \
            --non-interactive \
            --dry-run  # Remove --dry-run for actual deployment
    else
        echo "[ERROR] Unsupported DNS provider: $dns_provider_name"
        return 1
    fi
}


############################################
#               CHECK ARGS                 #
############################################

# Updates
sudo apt-get update -y

# Check if jq is installed
if ! command -v "jq" >/dev/null 2>&1; then
    # Install jq
    echo "[INFORMATION] Installing jq..."
    sudo apt-get install -y jq
    echo "[INFORMATION] Jq version: $(jq --version)"
    echo "[INFORMATION] Jq installed."
fi

# Check for the argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 '<json_string>'"
    exit 1
fi


############################################
#             SET VARIABLES                #  
############################################

# Read the argument into a variable
#json_input='{"ssl": {"enabled": "true", "dns_or_ip": "dns", "dns": "k8s-cluster-dev.mydomain.com"}, "haproxy": {"hostname": "haproxy-2-1", "lan_interface": "eth0", "ip": "192.168.3.14", "state": "MASTER", "router_id": "104", "priority": "100", "password": ",clwioji34hui3hiu3hiu", "vip":"192.168.3.50"}, "master_nodes": [{"hostname": "k8s-master-node-1-1-srv1", "ip": "192.168.3.11"}, {"hostname": "k8s-master-node-2-1-srv1", "ip": "192.168.3.12"}]}' # For testing
json_input=$1

# Parse the JSON to set variables
haproxy_hostname=$(echo "$json_input" | jq -r '.haproxy.hostname')
haproxy_lan_interface=$(echo "$json_input" | jq -r '.haproxy.lan_interface')
haproxy_ip=$(echo "$json_input" | jq -r '.haproxy.ip')
haproxy_state=$(echo "$json_input" | jq -r '.haproxy.state')
haproxy_router_id=$(echo "$json_input" | jq -r '.haproxy.router_id')
haproxy_priority=$(echo "$json_input" | jq -r '.haproxy.priority')
haproxy_pwd=$(echo "$json_input" | jq -r '.haproxy.password')
haproxy_vip=$(echo "$json_input" | jq -r '.haproxy.vip')
ssl_enabled=$(echo "$json_input" | jq -r '.ssl.enabled')
ssl_dns=$(echo "$json_input" | jq -r '.ssl.dns')
dns_or_ip=$(echo "$json_input" | jq -r '.ssl.dns_or_ip')
dns_provider=$(echo "$json_input" | jq -r '.ssl.dns_provider')
master_nodes=$(echo "$json_input" | jq -c '.master_nodes[]')


############################################
#                HAPROXY                   #  
############################################

# install ufw if it is not installed
if ! command -v "ufw" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing ufw..."
    sudo apt-get install -y ufw
    echo "[INFORMATION] UFW version: $(ufw --version)"
    echo "[INFORMATION] UFW installed."
fi

# Open ports 6443 and 443
sudo ufw --force enable
sudo ufw allow 6443
sudo ufw allow 443 && echo "[INFORMATION] Ports 443 and 6443 opened."

# Create and setup SSL certificate if enabled
if [ "$ssl_enabled" = "true" ]; then
    # print message
    echo "[INFORMATION] SSL is enabled."
    
    # Check if Certbot is installed
    if ! command -v certbot &> /dev/null; then
        echo "[INFORMATION] Certbot is not installed. Installing Certbot..."
        install_certbot
        echo "[INFORMATION] Obtaining certificates for the domain..."
    else
        echo "[INFORMATION] Certbot is already installed."
        echo "[INFORMATION] Obtaining certificates for the domain..."
    fi

    # Obtain a certificate
    obtain_certificate "$ssl_dns" "$dns_provider"

    # Preparing SSL certificates for HAProxy
    echo "[INFORMATION] Preparing SSL certificates for HAProxy..."
    sudo cat "/etc/letsencrypt/live/$ssl_dns/fullchain.pem" "/etc/letsencrypt/live/$ssl_dns/privkey.pem" | sudo tee "/etc/haproxy/certs/$ssl_dns.pem"
else
    echo "[INFORMATION] SSL is not enabled."
fi

# Install haproxy if not installed
if ! command -v "haproxy" >/dev/null 2>&1; then
    # Install haproxy
    echo "[INFORMATION] Installing haproxy..."
    sudo apt-get install -y haproxy
    echo "[INFORMATION] HAProxy version: $(haproxy --version)"
    echo "[INFORMATION] HAProxy installed."
    # Check if haproxy is running
    if ! systemctl is-active --quiet haproxy; then
        echo "[INFORMATION] Starting HAProxy..."
        sudo systemctl start haproxy
        echo "[INFORMATION] HAProxy started."
    else
        echo "[INFORMATION] HAProxy is already running."
    fi
fi

# If enbled SSL configure certificates on HAProxy
# otherwise configure the HAProxy without SSL
if [ "$ssl_enabled" = "true" ]; then
    # Start writing the HAProxy configuration (WITH SSL)
    {
        echo "frontend kubernetes-frontend"
        if [ "$dns_or_ip" = "dns" ]; then
            echo "    bind $ssl_dns:6443"
            echo "    bind $ssl_dns:443 ssl crt /etc/haproxy/certs/$ssl_dns.pem"
        else
            echo "    bind $haproxy_ip:6443"
            echo "    bind $haproxy_ip:443 ssl crt /etc/haproxy/certs/$ssl_dns.pem"
        fi        
        echo "    redirect scheme https if !{ ssl_fc }"
        echo "    mode tcp"
        echo "    option tcplog"
        echo "    default_backend kubernetes-backend"
        echo ""
        echo "backend kubernetes-backend"
        echo "    mode tcp"
        echo "    option tcp-check"
        echo "    balance roundrobin"
        echo "# === BEGIN MASTER NODES ==="
        # Loop through each master node and add it to the config
        while read -r node; do
            node_hostname=$(echo "$node" | jq -r '.hostname')
            node_ip=$(echo "$node" | jq -r '.ip')
            echo "    server $node_hostname $node_ip:6443 check fall 3 rise 2"
        done <<< "$master_nodes"
        echo "# === END MASTER NODES ==="
    } > "/etc/haproxy/haproxy.cfg"

    # Create a cron job (hook) to renew the certificate
    echo "[INFORMATION] Creating a cron job (hook) to renew the ssl certificates automatically..."
    haproxy_filename="haproxy-reload.sh"
    sudo cat "sudo systemctl reload haproxy" > "$haproxy_filename"
    sudo chmod +x "$haproxy_filename"
    sudo mv "$haproxy_filename" /etc/letsencrypt/renewal-hooks/deploy/

    # Restart and check the status of HAProxy
    echo "[INFORMATION] HAProxy configuration has been updated (with ssl)!"
    sudo "/etc/letsencrypt/renewal-hooks/deploy/$haproxy_filename"
else
    # Start writing the HAProxy configuration (NO SSL)
    {
        echo "frontend kubernetes-frontend"
        if [ "$dns_or_ip" = "dns" ]; then
            echo "    bind $ssl_dns:6443"
        else
            echo "    bind $haproxy_ip:6443"
        fi  
        echo "    mode tcp" 
        echo "    option tcplog"
        echo "    default_backend kubernetes-backend"
        echo ""
        echo "backend kubernetes-backend"
        echo "    mode tcp"
        echo "    option tcp-check"
        echo "    balance roundrobin"
        echo "# === BEGIN MASTER NODES ==="   
        # Loop through each master node and add it to the config
        while read -r node; do
            node_hostname=$(echo "$node" | jq -r '.hostname')
            node_ip=$(echo "$node" | jq -r '.ip')
            echo "    server $node_hostname $node_ip:6443 check fall 3 rise 2"
        done <<< "$master_nodes"
        echo "# === END MASTER NODES ==="
    } > "/etc/haproxy/haproxy.cfg"
    # Restart and check the status of HAProxy
    echo "[INFORMATION] HAProxy configuration has been updated (no ssl)!"
    sudo systemctl restart haproxy
fi
# Print message
echo "[INFORMATION] HAProxy has been restarted!"
sudo systemctl status haproxy.service


############################################
#               KEEPALIVED                 #  
############################################

# Install keepalived if not installed
if ! command -v "keepalived" >/dev/null 2>&1; then
    echo "[INFORMATION] Installing keepalived..."
    sudo apt-get install -y keepalived
    echo "[INFORMATION] Keepalived version: $(keepalived --version)"
    echo "[INFORMATION] Keepalived installed."
fi

# Write the configuration to keepalived.conf
sudo cat > /etc/keepalived/keepalived.conf <<EOF
vrrp_instance $haproxy_hostname {
    state $haproxy_state
    interface $haproxy_lan_interface
    virtual_router_id $haproxy_router_id
    priority $haproxy_priority
    authentication {
        auth_type PASS
        auth_pass $haproxy_pwd
    }
    virtual_ipaddress {
        $haproxy_vip
    }
}
EOF

# Start it and check the status of keepalived
sudo service keepalived start
echo "[INFORMATION] Keepalived configuration has been updated."
