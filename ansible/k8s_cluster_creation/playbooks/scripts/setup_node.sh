#!/bin/bash

# //////////////////////////////////////////////////////////
#   Setup Node                                             /
# //////////////////////////////////////////////////////////

# This command makes the script more robust 
# and it provides detailed debugging output.
# It helps ensure that errors are not ignored,
# uninitialized variables are caught, 
# and the script's behavior is clear and predictable.
set -euxo pipefail


############################################
# Functions                                #
############################################

# Setup worker node or backup master node
setup_worker_node_or_bck_control_plane() {
    local I_KUBECONFIG_PATH=$1
    local I_KUBECONFIG_METHOD=$2
    local I_CLUSTER_NAME=$3
    local I_HOME_DIRECTORY=$4
    local I_WORKER_OR_MASTER=$5

    # Read from local or one drive
    case "$I_KUBECONFIG_METHOD" in
    local)
        echo "[INFORMATION] Ansible playbook has uploaded the kubeconfig and kubeadm.json"
        ;;
    onedrive)
        echo "[INFORMATION] Moving kubeconfig and kubeadm.json to onedrive"
        sinaloa azure one-drive get-file -f "$I_KUBECONFIG_PATH/output_kubeadm.json" -g "$I_HOME_DIRECTORY/output_kubeadm.json"
        sinaloa azure one-drive get-file -f "$I_KUBECONFIG_PATH/admin.conf" -g "$I_HOME_DIRECTORY/admin.conf"
        ;;
    *)
        echo "[ERROR] Unknown KUBECONFIG_METHOD: $KUBECONFIG_METHOD"
        exit 1
        ;;
    esac

    # Configure kubeconfig
    sudo cp admin.conf /etc/kubernetes # only for workers
    sudo cp -i /etc/kubernetes/admin.conf $I_HOME_DIRECTORY/.kube/config
    # Configuring kube commands also for root user
    sudo mkdir -p /root/.kube && sudo cp $I_HOME_DIRECTORY/.kube/config /root/.kube/config && sudo chown root:root /root/.kube/config

    # Read the JSON data from the file
    json_data=$(cat output_kubeadm.json)

    # Parse the JSON data using jq and extract the values
    endpoint=$(echo "$json_data" | jq -r '.endpoint')
    port=$(echo "$json_data" | jq -r '.port')
    token=$(echo "$json_data" | jq -r '.token')
    cert_hash=$(echo "$json_data" | jq -r '.cert_hash')
    cert_key=$(echo "$json_data" | jq -r '.cert_key')

    # Join to master node
    if [[ "$I_WORKER_OR_MASTER" == "worker" ]]; then
        # Worker
        sudo kubeadm join "$endpoint:$port" --token "$token" --discovery-token-ca-cert-hash "$cert_hash"
    else
        # Master node backup
        sudo kubeadm join "$endpoint:$port" --token "$token" --discovery-token-ca-cert-hash "$cert_hash" --control-plane --certificate-key "$cert_key"
    fi  
}


############################################
# Start script... Checking input arguments #
############################################

# Check if provided the type of node
if [[ "$1" == "" ]]; then
    echo "Error, provide the node type (worker or master)"   
    exit 1
fi

# Check if all arguments are provided
if [[ "$#" != 14 ]]; then
    echo "Usage for master node: $0 <NODE_TYPE> <NODENAME> <CLUSTER_NAME> <NODE_IP> <POD_CIDR> <HOME_DIRECTORY> <NODE_MASTER_TYPE> <HAPROXY_ENABLED> <HAPROXY_PORT> <HAPROXY_DNS_OR_IP> <HAPROXY_IP> <HAPROXY_DNS> <KUBECONFIG_PATH> <KUBECONFIG_METHOD>"
    echo "Example: ./setup_node.sh \"master\" \"k8s-master-node-1-1-srv1\" \"dale-prod\" \"dale-k8s-infra\" \"192.168.1.45\" \"10.244.0.0/16\" \"/home/dalecosta/\" \"master\" \"true\" \"443\" \"dns\" \"192.168.3.100\" \"k8s-cluster-dev.dalecosta.com\" \"/user/bin/k8s_configs\" \"local\""
    exit 1
fi


############################################
# Init                                     #
############################################

# Declare variables
# For debug
#NODE_TYPE="master"
#NODENAME=$(hostname -s)
#NODE_IP="192.168.3.234"
#POD_CIDR="10.244.0.0/16"
#CLUSTER_NAME="dale-dev"
#HOME_DIRECTORY="$HOME"
#NODE_MASTER_TYPE="backup"
#CONTROL_PLAN_ENDPOINT=""
#HAPROXY_ENABLED="true"
#HAPROXY_PORT="443"
#HAPROXY_DNS_OR_IP="dns"
#HAPROXY_IP="192.168.3.100"
#HAPROXY_DNS="k8s-cluster-dev.dalecosta.com"
#KUBECONFIG_PATH="/root/workspace/"
#KUBECONFIG_METHOD="" # Method where store the .kubeconfig --> local, onedrive
NODE_TYPE="" # The node is worker or master
NODENAME="" # Node name
NODE_IP="" # Ip of the node
POD_CIDR="" # POD CIDR
CLUSTER_NAME="" # Name of the cluster you are going to create
HOME_DIRECTORY="" # Path of $HOME to download and save temporary files
NODE_MASTER_TYPE="" # The node is master or backup master
CONTROL_PLAN_ENDPOINT="" # The endpoint of the control plan (haproxy dns or ip)
HAPROXY_ENABLED="" # If enabled haproxy
HAPROXY_PORT="" # Port of haproxy
HAPROXY_DNS_OR_IP="" # If haproxy is configured with dns or ip
HAPROXY_IP="" # Ip of haproxy
HAPROXY_DNS="" # Dns of haproxy
KUBECONFIG_PATH="" # Path to save kubeconfig locally if selected local
KUBECONFIG_METHOD="" # Method where store the .kubeconfig --> local, onedrive

# Variables not set from args
kubeadm_output="" # Variable used to get the output of kubeadm command to store info about master node

# Populate variables with args
NODE_TYPE="$1"
NODENAME="$2"
CLUSTER_NAME="$3"
NODE_IP="$4"
POD_CIDR="$5"
HOME_DIRECTORY="$6"
NODE_MASTER_TYPE="$7"
CONTROL_PLANE_ENDPOINT=""
HAPROXY_ENABLED="$8"
HAPROXY_PORT="$9"
HAPROXY_DNS_OR_IP="${10}"
HAPROXY_IP="${11}"
HAPROXY_DNS="${12}"
KUBECONFIG_PATH="${13}"
KUBECONFIG_METHOD="${14}"

# Set the control plan 
# endpoint if enabled haproxy...
# Check if configured haproxy first...
if [[ "$HAPROXY_ENABLED" == "true" ]]; then
    # Check if the haproxy is configured with dns or ip
    if [[ "$HAPROXY_DNS_OR_IP" == "dns" ]]; then
        # Set enpoint with dns
        CONTROL_PLAN_ENDPOINT="$HAPROXY_DNS"
    else
        # Set enpoint with ip
        CONTROL_PLAN_ENDPOINT="$HAPROXY_IP"
    fi
fi

# Enable sinaloa cli to make accessible by user without sudo
sudo chmod +x "/usr/local/bin/sinaloa"

#################################################################
# If enabled haproxy with dns, add to etc/hosts the ip with dns #
#################################################################

# Check if HAProxy is enabled
FINAL_MSG="Skippping the process of adding HAProxy IP and DNS to /etc/hosts..."
if [ "$HAPROXY_ENABLED" == "true" ]; then
    # Check if HAProxy DNS is provided
    if [ -n "$HAPROXY_DNS" ]; then
        # Add HAProxy IP and DNS to /etc/hosts
        echo "$HAPROXY_IP $HAPROXY_DNS" | sudo tee -a /etc/hosts
        echo "[INFORMATION] HAProxy DNS configured!"
    else
        echo "[INFORMATION] HAProxy DNS not configured, $FINAL_MSG"
    fi
else
    echo "[INFORMATION] HAProxy is not enabled, $FINAL_MSG"
fi


############################################
# Setup node (master or worker)            #
############################################

# If the node is master node configure it otherwise configure 
# it as worker node or backup control plane.
if [[ "$NODE_TYPE" == "master" ]]; then
    # Before to configure the masternode,
    # we need to understand if the node is the master node (master)
    # or is configured as a backup master node...
    # If the node is a backup master node,
    # we need to configure different from the real master node.
    if [[ "$NODE_MASTER_TYPE" == "master" ]]; then
        ##################################################
        # Setup for control plane (master node - master) #
        ##################################################

        # Pull required images
        sudo kubeadm config images pull

        # Initialize kubeadm based on haproxy enabled or not
        # - HAPROXY NOT ENABLED: In this case, the master node is the control plane endpoint
        # - HAPROXY ENABLED: In this case, the haproxy with virtual ip is the control plane endpoint
        if [[ "$HAPROXY_ENABLED" == "false" ]]; then
            # With clusters that use a single master node as the control plane endpoint (no HAProxy or other load balancer)
            # --> [Kubernetes Cluster Without Load Balancer]
            #
            # - API Server Accessibility:
            #   If the first master node (used as the control plane endpoint) fails, 
            #   kubectl and worker nodes lose access to the API server, blocking cluster management.
            #
            # - Control Plane Components:
            #   Other control plane nodes may still run components like kube-scheduler or kube-controller-manager,
            #   but they rely on the kube-apiserver. Without a reachable API server, the control plane is partially down.
            #
            # - etcd Quorum:
            #   If etcd quorum is maintained, the cluster state is preserved. However, accessing or modifying it requires
            #   the API server to be reachable.
            #
            # - Workloads:
            #   Existing workloads (pods) may continue running if the worker nodes remain healthy, but no new deployments,
            #   scaling, or config changes can be applied.
            #
            # Summary:
            #   Without a load balancer or DNS-based failover for the API server endpoint, the cluster enters a degraded state
            #   if the designated master node fails. Having multiple master nodes helps maintain etcd quorum, but a load balancer
            #   is essential to ensure API server availability and true high-availability.
            kubeadm_output=$(sudo kubeadm init --upload-certs --apiserver-advertise-address="$NODE_IP" --apiserver-cert-extra-sans="$NODE_IP" --pod-network-cidr="$POD_CIDR" --node-name "$NODENAME" --ignore-preflight-errors Swap) # Ingnore preflight errors enabled for old versions of k8s 
        else
            # With cluster that use a haproxy as control plane endpoint (with haproxy as loadbalancer).          
            kubeadm_output=$(sudo kubeadm init --upload-certs --apiserver-advertise-address="$NODE_IP" --apiserver-cert-extra-sans="$CONTROL_PLAN_ENDPOINT" --pod-network-cidr="$POD_CIDR" --node-name "$NODENAME" --ignore-preflight-errors Swap) # Ingnore preflight errors enabled for old versions of k8s 
        fi

        # Change the cluster name of the kubeconfig (admin.config),
        # check if the Kubernetes configuration file exists
        if [ -f "/etc/kubernetes/admin.conf" ]; then
            new_cluster_name="$CLUSTER_NAME"
            kubeconfig_path="/etc/kubernetes/admin.conf"

            # Update the cluster name in the 'clusters' e 'contexts' sections
            sudo sed -i "s/^    name: kubernetes$/    name: $new_cluster_name/" "$kubeconfig_path"
            sudo sed -i "s/cluster: kubernetes/cluster: $new_cluster_name/g" "$kubeconfig_path"
            sudo sed -i "s/kubernetes-admin@kubernetes$/kubernetes-admin@$new_cluster_name/" "$kubeconfig_path"
            # Cleaning the .kubeconfig
            sudo sed -i "s/name: kubernetes/name: $new_cluster_name/g" "$kubeconfig_path"
            sudo sed -i "s/- name: $new_cluster_name-admin/- name: kubernetes-admin/g" "$kubeconfig_path"
            sudo sed -i "s/name: $new_cluster_name-admin@$new_cluster_name/name: kubernetes-admin@$new_cluster_name/g" "$kubeconfig_path"

            echo "[INFORMATION] Kubernetes cluster name and context updated with cluster name '$new_cluster_name'"
        else
            echo "[INFORMATION] Kubernetes configuration file not found at '/etc/kubernetes/admin.conf'"
        fi

        # Extract the required informations using grep
        # This infos will be used by workers to join on cluster
        endpoint="$(echo "$kubeadm_output" | grep -oP 'kubeadm join \K[^:]+(?=:)')"
        port=$(echo "$kubeadm_output" | grep -oP 'kubeadm join \K[^ ]+' | awk -F ':' '{print $2}')
        token=$(echo "$kubeadm_output" | grep -oP 'token \K[^ ]+')
        cert_hash=$(echo "$kubeadm_output" | grep -oP 'sha256:\S+')
        # Get cert. keys for a future control plane configuration
        certificate_key=$(sudo kubeadm init phase upload-certs --upload-certs | awk '/Using certificate key:/ {getline; print}')

        # Create and save infos on JSON file
        echo "{\"endpoint\":\"$endpoint\", \"port\":\"$port\", \"token\":\"$token\", \"cert_hash\":\"$cert_hash\", \"cert_key\":\"$certificate_key\"}" > "$HOME_DIRECTORY/output_kubeadm.json"

        # Configure kubeconfig
        # (mkdir -p $HOME_DIRECTORY/.kube) # --> Done by ansible
        sudo cp -i /etc/kubernetes/admin.conf $HOME_DIRECTORY/.kube/config
        # sudo chown $(id -u):$(id -g) $HOME_DIRECTORY/.kube/config # --> Done by ansible
        # Configuring kube commands also for root user
        sudo mkdir -p /root/.kube && sudo cp $HOME_DIRECTORY/.kube/config /root/.kube/config && sudo chown root:root /root/.kube/config

        # Install Calico Network (Plugin Network)  
        # tigera-operator
        # original --> https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml  
        sudo kubectl create -f "$HOME_DIRECTORY"/tigera_operator.yml
        
        # Custom resources
        # original --> https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
        # Use sed to replace the CIDR in the 
        # YAML file with the value of POD_CIDR variables
        sudo sed -i "s|10.244.0.0/16|$POD_CIDR|g" "$HOME_DIRECTORY/custom_resources.yml"
        sudo kubectl create -f "$HOME_DIRECTORY"/custom_resources.yml # Create pods

        # Copy the json and the "/etc/kubernetes/admin.conf"
        # so then, wokers can download the configurations to join on cluster
        case "$KUBECONFIG_METHOD" in
        local)
            echo "[INFORMATION] On ansible will download during the playbook the kubeconfig and kubeadm.json"
            ;;
        onedrive)
            echo "[INFORMATION] Moving kubeconfig and kubeadm.json to onedrive"
            sinaloa azure one-drive upload-file -f "$HOME_DIRECTORY/output_kubeadm.json" -g "$KUBECONFIG_PATH/output_kubeadm.json"
            sinaloa azure one-drive upload-file -f "$HOME_DIRECTORY/.kube/config" -g "$KUBECONFIG_PATH/admin.conf"
            ;;
        *)
            echo "[ERROR] Unknown KUBECONFIG_METHOD: $KUBECONFIG_METHOD"
            exit 1
            ;;
        esac
    else
        ######################################################
        # Setup for bck control plane (master node - backup) #
        ######################################################
        setup_worker_node_or_bck_control_plane "$KUBECONFIG_PATH" "$KUBECONFIG_METHOD" "$CLUSTER_NAME" "$HOME_DIRECTORY" "master_bck"
    fi
else
    ############################################
    # Setup for worker node                    #
    ############################################
    setup_worker_node_or_bck_control_plane "$KUBECONFIG_PATH" "$KUBECONFIG_METHOD" "$CLUSTER_NAME" "$HOME_DIRECTORY" "worker"
fi

# Cleaning
sudo rm -rf .wget-hsts
sudo find . -type f -name "go*.tar.gz" -exec rm -f {} \;
sudo find . -type f -name "wget*" -exec rm -f {} \;
sudo rm -rf /tmp/terraform_*.zip

# Print ok message
echo "[INFORMATION] Node initialized correctly, operation successfully completed :)"
