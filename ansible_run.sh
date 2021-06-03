#!/bin/bash

set -x -o pipefail

KNOWN_HOSTS="$HOME/.ssh/known_hosts"
TMPHOSTS=$(mktemp)
HOSTRESOLV=0
HOSTFILE="/etc/ansible/hosts"
IFS=$'\n'

if [ ! -r "$KNOWN_HOSTS" ]; then
  echo "Verify the $KNOWN_HOSTS file."
fi

if ! command -v vagrant 1>/dev/null; then
  exit 1
fi

if ! vagrant validate Vagrantfile; then
  exit 1
fi

if ! find . -type f -name '*.y*ml' ! -name '.*' -print0 | \
  xargs -0 ansible-lint; then
    echo "ansible-lint failed."
    exit 1
fi

if ! find . -type f -name '*.y*ml' ! -name '.*' -print0 | \
  xargs -0 yamllint -d "{extends: default, rules: {line-length: {level: warning}}}"; then
    echo "yamllint failed."
    exit 1
fi

if [ "$1" = "vagrant" ]; then
  if [ "$(vagrant status | grep -c 'running.*virtualbox')" -le 0 ]; then
    echo "No vagrant boxes are running. Exiting."
    exit 1
  fi

  if [ ! -r "./hosts" ] && [ ! -r "./.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory" ] || [ "$2" = "hosts" ]; then
    echo "Generating Ansible hosts file using Vagrant."
    {
      echo "[vagrant]"
      for VM in $(vagrant status | grep -iE 'running.*virtualbox' | awk '{print $1}'); do
        mapfile -t VAGRANT_SSH < <(vagrant ssh-config "$VM" | awk '{print $NF}')
        echo "${VAGRANT_SSH[0]} ansible_host=${VAGRANT_SSH[1]} ansible_user=${VAGRANT_SSH[2]} ansible_port=${VAGRANT_SSH[3]} ansible_private_key_file=${VAGRANT_SSH[7]}"
      done
    } > ./hosts
    HOSTFILE="./hosts"
  elif [ -r "./.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory" ]; then
    HOSTFILE="./.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory"
  elif [ -r "./hosts" ]; then
    HOSTFILE="./hosts"
    echo "./hosts file exists. Won't overwrite."
  else
    echo "Vagrant hosts flag not set."
  fi
fi

if [ -r "$HOSTFILE" ]; then
  echo "Using $HOSTFILE."
else
  echo "No working host file. Exiting."
  exit 1
fi

if [ -r /etc/ansible/hosts ] && [ "$1" != "vagrant" ]; then
  for host in $(grep -E -v '#|\[' /etc/ansible/hosts | awk '{print $1}' | uniq); do
    if dig +answer "$1" | grep -q 'status: NOERROR'; then
      ssh-keyscan -H "$host" >> "$TMPHOSTS"
    else
      echo "$host doesn't resolve, leaving $KNOWN_HOSTS untouched."
      HOSTRESOLV=1
    fi
  done

  if [ $HOSTRESOLV = 0 ]; then
    echo
    echo "Generating $KNOWN_HOSTS. Saving current to $KNOWN_HOSTS.bak"
    cp -v "$KNOWN_HOSTS" "$KNOWN_HOSTS.bak"
    sort "$TMPHOSTS" | uniq > "$KNOWN_HOSTS"
  fi
fi

rm "$TMPHOSTS"

ansible-playbook all.yml -i "$HOSTFILE" --timeout 30
