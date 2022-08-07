#!/bin/bash

# Master Node configuration
MASTER_NODE_CPU=2
MASTER_NODE_MEMORY=1024M
MASTER_NODE_DISK=3G
MASTER_NODE_HOSTNAME=k3s-master

# Node configuration
WORKER_NODE_CPU=1
WORKER_NODE_MEMORY=1024M
WORKER_NODE_DISK=3G
WORKER_NODE_HOSTNAME=k3s-worker-

# Number of kubernetes nodes
export WNNODES=2

# Test if multipass is installed and if not, install it
snap services multipass | grep -q "^multipass"
if [ $? -eq 0 ]; then
    echo "multipass is already installed"
else
    sudo snap install multipass --classic --stable
fi

# Create k3s master node
multipass launch \
    --name $MASTER_NODE_HOSTNAME \
    --cpus $MASTER_NODE_CPU \
    --mem $MASTER_NODE_MEMORY \
    --disk $MASTER_NODE_DISK

# Install k3s on master node
multipass exec $MASTER_NODE_HOSTNAME -- /bin/bash -c "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -"

# Multipass echo ipv4 address of master node
multipass exec $MASTER_NODE_HOSTNAME -- /bin/bash -c "ip addr show ens3 | grep -Po 'inet \K[\d.]+'"

export K3S_NODEIP_MASTER=`multipass exec $MASTER_NODE_HOSTNAME -- /bin/bash -c "ip addr show ens3 | grep -Po 'inet \K[\d.]+'"`

export K3S_NODE_URL="https://$K3S_NODEIP_MASTER:6443"

# Export K3S cluster token on master to be used in worker to join the cluster
export K3S_MASTER_TOKEN=`multipass exec $MASTER_NODE_HOSTNAME sudo cat /var/lib/rancher/k3s/server/node-token`

# if Number of kubernetes nodes is greater than 0, then create worker nodes, else exit
if [ $WNNODES -gt 0 ]; 
    then
        # Create K3S nodes corresponding to the number of nodes specified in NNODES
        for i in $(seq 1 $WNNODES); do
            multipass launch \
                --name $WORKER_NODE_HOSTNAME$i\
                --cpus $WORKER_NODE_CPU \
                --mem $WORKER_NODE_MEMORY \
                --disk $WORKER_NODE_DISK
            multipass exec $WORKER_NODE_HOSTNAME$i -- /bin/bash -c "curl -sfL https://get.k3s.io | K3S_TOKEN=${K3S_MASTER_TOKEN} K3S_URL=${K3S_NODE_URL} sh -"
        done
    else
        echo "No worker nodes to create"
        echo "Node master url: $K3S_NODE_URL"
        exit 0
fi

