#!/bin/bash

# Copy project folder to the hypervisor
scp -r ../../multipass-k3s-cluster trost@192.168.1.6:/home/trost
