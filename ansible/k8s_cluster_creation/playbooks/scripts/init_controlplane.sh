#!/bin/bash

# //////////////////////////////////////////////////////////
#   Setup ControlPlane Endpoint                            /
# //////////////////////////////////////////////////////////

set -euxo pipefail

############################################
# Check input arguments                    #
############################################
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <CONTROL_PLANE_IP> <PORT>"
    echo "Example: ./init_controlplane.sh 192.168.4.56 6443"
    exit 1
fi

ENDPOINT_IP="$1"
ENDPOINT_PORT="$2"
ENDPOINT="${ENDPOINT_IP}:${ENDPOINT_PORT}"

RAW_FILE="raw-kubeadm-config.yaml"
FINAL_FILE="kubeadm-config.yaml"

############################################
# Dump the current kubeadm configuration   #
############################################
echo "[1/4] Dumping kubeadm-config..."
sudo kubectl get configmap kubeadm-config -n kube-system -o yaml > "$RAW_FILE"

############################################
# Extract configuration blocks             #
############################################
echo "[2/4] Extracting configuration blocks..."

# Get InitConfiguration or use a default if missing
init_block=$(yq -r '.data.InitConfiguration' "$RAW_FILE")
if [ "$init_block" = "null" ] || [ -z "$init_block" ]; then
    echo "[INFO] InitConfiguration not found. Using default template..."
    init_block=$(cat <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
localAPIEndpoint:
  advertiseAddress: ${ENDPOINT_IP}
  bindPort: ${ENDPOINT_PORT}
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  name: node
  taints: null
timeouts:
  controlPlaneComponentHealthCheck: 4m0s
  discovery: 5m0s
  etcdAPICall: 2m0s
  kubeletHealthCheck: 4m0s
  kubernetesAPICall: 1m0s
  tlsBootstrap: 5m0s
  upgradeManifests: 5m0s
EOF
    )
else
    echo "[INFO] InitConfiguration loaded from configmap."
fi

# Extract ClusterConfiguration
cluster_block=$(yq -r '.data.ClusterConfiguration' "$RAW_FILE")

# Check and add controlPlaneEndpoint if missing
if ! echo "$cluster_block" | grep -q "controlPlaneEndpoint:"; then
    echo "[INFO] Adding controlPlaneEndpoint: ${ENDPOINT}"
    # Append controlPlaneEndpoint at the end of the ClusterConfiguration
    cluster_block="${cluster_block}"$'\n'"controlPlaneEndpoint: \"${ENDPOINT}\""
fi

############################################
# Write the new configuration              #
############################################
echo "[3/4] Writing kubeadm-config.yaml..."
{
    echo "$init_block"
    echo "---"
    echo "$cluster_block"
} > "$FINAL_FILE"

############################################
# Upload configuration to cluster          #
############################################
echo "[4/4] Uploading config with kubeadm..."
sudo kubeadm init phase upload-config kubeadm --config "$FINAL_FILE"

# Cleanup
rm -f "$RAW_FILE" "$FINAL_FILE"

echo "[INFO] Done. Configuration uploaded successfully."
