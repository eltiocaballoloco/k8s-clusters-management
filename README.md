
# K8S-CLUSTERS-MANAGEMENT

In-house k8s cluster creation which is a versatile tool leverages Ansible for automation. With the UI you can generate the manifests and the json to run the ansible playbooks via bash script, creating a k8s cluster with kubeadm (RKE). There is also the possibility to add new nodes on the cluster. The configuration of the k8s cluster is valid for an on-prem scenario and also for cloud providers such as azure, aws, google, digital ocean, etc... with virtual machines.


## 🪅 Compatibility

This project can be executed on the following platforms:

- Windows 11 (using Ubuntu via WSL)
- MacOS (arm & amd)
- Ubuntu 22.04

Cluster node OS availables:

- Ubuntu Server (at least 22.04)


## ☁️ Cloud providers integration

It is possible configures a k8s cluster also with vms running on cloud providers such as azure, aws, digital ocean, google, etc...
To integrate this tool with vms on cloud, there are two possible scenarios:

- Vms on VPC (Virtual Private Cloud): In this case th ip provided on UI or added manually on json and manifests can be the private ip of the VPC where virtual machines run. In this case if it is not possible reach the vms on public internet, run this project on a local VPC vm using the internal ip (private ip inside the VPC). Keep in mind that all vms have to connect on internet to configure the packages repositories. 

- Public vms: If you istance public vms or you create a VPC reachable by the external network, it is possible use the public ip of every single vm.

If you work on an on-prem network, you can use the internal nodes ip of the network (eg: 192.168.1.214, 192.168.1.101, 192.168.1.45).


## 👨‍💻 Tech Stack

**UI:** react-ts

**BE:** ansible, bash, YAML & json


## 🎰 Installation

Check if there are the folder '.kube' on home user profile directory. If there isn't, create it:

```bash
  cd $HOME
  mkdir .kube
```

Check the folder 'config' inside '.kube'. If there isn't, create it:

```bash
  cd $HOME
  mkdir .kube/config
```

Now go inside the folder where you want clone the project
(advice: clone the repo on folders such as 'workspace' or 'source' under user profile):

```bash
  git clone https://github.com/eltiocaballoloco/k8s-clusters-management.git
  cd k8s-clusters-management
```

When inside the repo, we need to make executable the 'setup.sh':

```bash
  sudo chmod +x setup.sh
```

Now it is possible start the setup:

```bash
  ./setup.sh
```

After the execution of the setup, is possible start the UI 
to get the manifests to start the creation of the k8s cluster.


## 🖥 UI

To generate the manifests and the YAML files, to run the bash script, is possible start the ui to get the files required. To start the UI enter on ui folder:

```bash
  cd ui
```

If not installed, install npm packages (operation done during the 'setup.sh' execution):

```bash
  npm i && npm i --save-dev @types/file-saver
```

Start UI:

```bash
  npm run start
```

Compile the for 'Cluster creation' to generate the manifests.


## 🚀 BE - Create new cluster

Before to start, understand that ansible work with underscore, so all files inside the folders 'ansible' and 'scripts' are with underscore. Use this nomenclature please. Once you got the manifests, put the YAML inside inside a new folder under ansible/k8s_cluster_creation/inventory/group_vars. The folder it is preferible that it is called as the name of the cluster eg: cluster_dev --> So put YAML into ansible/k8s_cluster_creation/inventory/group_vars/cluster_dev.

Make sure 'configure_cluster.sh' is executable (done by the script setup.sh):

```bash
  cd k8s-clusters-management
  sudo chmod +x scripts/k8s_cluster_creation/configure_cluster.sh
```

After this, put the json file inside the folder scripts/k8s_cluster_creation/json.
Create the folder json and add the json file downlaoded from UI, eg: scripts/k8s_cluster_creation/json/cluster_dev.json
Now, go on root folder of the git project:

- MacOS:
```bash
  sudo -s
  cd k8s-clusters-management
  # Start the bash script... eg: ./scripts/k8s_cluster_creation/configure_cluster.sh cluster_dev.json
  sudo ./scripts/k8s_cluster_creation/configure_cluster.sh <json_file_name>
  # Or if you are using onedrive
  sudo -E ./scripts/k8s_cluster_creation/configure_cluster.sh <json_file_name>
```

- Ubuntu:
```bash
  cd k8s-clusters-management
  # Start the bash script... eg: . scripts/k8s_cluster_creation/configure_cluster.sh cluster_dev.json
  sudo . scripts/k8s_cluster_creation/configure_cluster.sh <json_file_name>
  # Or if you are using onedrive
  sudo -E . scripts/k8s_cluster_creation/configure_cluster.sh <json_file_name>
```

Start the script 'configure_cluster.sh' passing by arg. the name of the file json with the nodes configurations to create the cluster. The script will start the execution of the procedure. 

At the end the procedure if doing 'kubectl get nodes' you get error:

```bash
#W1125 23:56:55.773104   29968 loader.go:221] Config not found: /Users/user1/.kube/devops/config
#The connection to the server localhost:8080 was refused - did you specify the right host or port?
#OR
#error: error loading config file "/Users/user1/.kube/config": read /Users/user1/.kube/config: is a directory
```

You need to do the export PATH manually. To do it,
is necessary copy and past the command suggested by the script 'configure_cluster.sh' at the end of the script:

```bash
#[INFORMATION] If 'kubectl get nodes' does not return the number of nodes on the cluster, maybe you need to run 'export KUBECONFIG' manually. Open the terminal and copy-past this: 'export KUBECONFIG="/Users/user1/.kube/cluster-dev/config"'
#[INFORMATION] Kubeconfig configured correctly on the local machine: /Users/user1/.kube/cluster-dev/config
```

Now, after you copy the suggested export, on terminal try again 'kubectl get nodes':

```bash
export KUBECONFIG="/Users/user1/.kube/cluster-dev/config"
kubectl get nodes                                                                                       
#NAME                  STATUS   ROLES                  AGE     VERSION
#k8s-master-node-1-1   Ready    control-plane,master   20m     v1.28.4
#k8s-worker-node-1-2   Ready    worker                 2m38s   v1.28.4
```

## 🚀 BE - Add new nodes

If you need to add new nodes to the cluster, just add a
new entity in the array of the json 'add_new_nodes':

```json
  {
    ...others properties...
    "nodes_to_add": [
      {
        "node_type": "worker",
        "ssh_user_password": "password_user",
        "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/dev/k8s_worker_node_1_4_srv1.yml",
        "hostname": "k8s-worker-node-1-4-srv1",
        "ip": "192.168.3.39",
        "physical_env": "srv1",
        "ssh_username": "worker-user",
        "ssh_key_path": "/Users/user-1/id_rsa",
        "net_ports_conf": "true",
        "ports_open_method": "worker",
        "ansible_host": "k8s-worker-node-1-4-srv1.dalecosta.com",
        "master_type": "not_configured"
      },
      {
        "node_type": "worker",
        "ssh_user_password": "password_user",
        "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/dev/k8s_worker_node_1_5_srv1.yml",
        "hostname": "k8s-worker-node-1-5-srv1",
        "ip": "192.168.3.40",
        "physical_env": "srv1",
        "ssh_username": "worker-user",
        "ssh_key_path": "/Users/user-1/id_rsa",
        "net_ports_conf": "true",
        "ports_open_method": "worker",
        "ansible_host": "k8s-worker-node-1-5-srv1.dalecosta.com",
        "master_type": "not_configured"
      }  
    ] 
  }
```

Now is possible run again the script:

- MacOS:
```bash
  sudo -s
  cd k8s-clusters-management
  # Start the bash script... eg: ./scripts/k8s_cluster_creation/configure_cluster.sh cluster_dev.json
  sudo ./scripts/k8s_cluster_creation/configure_cluster.sh <json_file_name>
  # Or if you are using onedrive
  sudo -E ./scripts/k8s_cluster_creation/configure_cluster.sh <json_file_name>
```

- Ubuntu:
```bash
  cd k8s-clusters-management
  # Start the bash script... eg: . scripts/k8s_cluster_creation/configure_cluster.sh cluster_dev.json
  sudo . scripts/k8s_cluster_creation/configure_cluster.sh <json_file_name>
  # Or if you are using onedrive
  sudo -E . scripts/k8s_cluster_creation/configure_cluster.sh <json_file_name>
```

## 📜 Template YAML

```yaml
##########################
# node variables         #
##########################
ansible_host: "k8s-master-node-2-1-srv1.dalecosta.com"
node_name: "k8s-master-node-2-1-srv1"
node_ssh_user: "masternode21"
ssh_private_key_path: "/Users/user-1/id_rsa"
ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
kubeconfig_method: "local"
kubeconfig_path: "/Users/user-1/.kube"
cluster_name: "dev"

##########################
# tools variables        #
##########################
# init_node.sh
k8s_version: "1.32.0-1.1"
cri_version: "1.28"
cri_os: "xUbuntu_22.04"
required_ports: "true"
open_ports_for_master_or_worker: "master"
json_hostnames: "{\\\"hostnames\\\":[{\\\"hostname\\\":\\\"k8s-master-node-2-1-srv1\\\",\\\"ip\\\":\\\"192.168.3.33\\\"},{\\\"hostname\\\":\\\"k8s-worker-node-2-2-srv1\\\",\\\"ip\\\":\\\"192.168.3.34\\\"},{\\\"hostname\\\":\\\"k8s-worker-node-2-3-srv1\\\",\\\"ip\\\":\\\"192.168.3.35\\\"}]}"

# To add a new nodes
new_json_hostnames: ""

# setup_node.sh
node_type: "master"
master_type: "master"
node_ip: "192.168.3.33"
pod_cidr: "10.244.0.0/16"

##########################
# system variables       #
##########################
env: "srv1"
local_path_git: "/Users/user-1/Workspace/k8s-clusters-management"

############################
# haproxy (not configured) #
############################
haproxy_enabled: "false"
haproxy_port: "6443"
haproxy_dns_or_ip: "ip"
haproxy_ip: ""
haproxy_dns: ""
haproxy_dns_provider: "not_configured"
```


## 📜 Template json

```json
{
  "path_vars_file_master_node_ansible": "ansible/k8s_cluster_creation/inventory/group_vars/dev/k8s_master_node_2_1_srv1.yml",
  "ssh_user_password_master_node": "password",
  "cluster_name": "dev",
  "kubeconfig_method": "local",
  "kubeconfig_path": "/Users/user-1/.kube",
  "kubeconfig_setup": "true",
  "pod_cidr": "10.244.0.0/16",
  "k8s_version": "1.32.3-1.1",
  "cri_version": "1.28",
  "cri_os": "xUbuntu_22.04",
  "ports_env": "prod",
  "project_git_path": "/Users/user-1/Workspace/k8s-clusters-management",
  "nodes_to_configure": [
    {
      "node_type": "master",
      "ssh_user_password": "password",
      "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/dev/k8s_master_node_2_1_srv1.yml",
      "hostname": "k8s-master-node-2-1-srv1",
      "ip": "192.168.3.33",
      "physical_env": "srv1",
      "ssh_username": "master-user",
      "ssh_key_path": "/Users/user-1/Workspace/ssh-keys/id_rsa",
      "net_ports_conf": "true",
      "ports_open_method": "master",
      "ansible_host": "k8s-master-node-2-1-srv1.dalecosta.com",
      "master_type": "master"
    },
    {
      "node_type": "worker",
      "ssh_user_password": "password",
      "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/dev/k8s_worker_node_2_2_srv1.yml",
      "hostname": "k8s-worker-node-2-2-srv1",
      "ip": "192.168.3.34",
      "physical_env": "srv1",
      "ssh_username": "worker-user",
      "ssh_key_path": "/Users/user-1/Workspace/ssh-keys/id_rsa",
      "net_ports_conf": "true",
      "ports_open_method": "worker",
      "ansible_host": "k8s-worker-node-2-2-srv1.dalecosta.com",
      "master_type": "not_configured"
    },
    {
      "node_type": "worker",
      "ssh_user_password": "password",
      "path_vars_ansible_file": "ansible/k8s_cluster_creation/inventory/group_vars/dev/k8s_worker_node_2_3_srv1.yml",
      "hostname": "k8s-worker-node-2-3-srv1",
      "ip": "192.168.3.35",
      "physical_env": "srv1",
      "ssh_username": "worker-user",
      "ssh_key_path": "/Users/user-1/Workspace/ssh-keys/id_rsa",
      "net_ports_conf": "true",
      "ports_open_method": "worker",
      "ansible_host": "k8s-worker-node-2-3-srv1.dalecosta.com",
      "master_type": "not_configured"
    }
  ],
  "nodes_to_add": [],
  "haproxy": {
    "enabled": "false", // Not configured 
    "ssl": {
      "enabled": "false",
      "dns": "",
      "dns_or_ip": "ip",
      "port": "6443",
      "dns_provider": "not_configured"
    },
    "haproxy_common_cfg": {
      "password": "",
      "vip": ""
    },
    "haproxy_to_configure": [],
    "haproxy_to_add": []
  }
}
```


## 📖 Env variables
If you want use onedrive instead of save only locally the k8s configuration file,
You need to set the env variables in the machine you execute this tool.
The variables required for one drive, are the following:
```bash
export AZURE_TENANT_ID="tenant_id"
export AZURE_CLIENT_ID="client_id"
export AZURE_CLIENT_SECRET="client_secret"
export AZURE_DRIVE_ID="drive_id"
```
This is useful because you don't need to keep the local configurations in your machine, but you can save it on onedrive. During the process, it will connect to onedrive instead of take file from your local environment.