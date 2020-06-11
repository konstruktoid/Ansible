#!/bin/bash
set -x -o pipefail

if ! command -v ansible 1>/dev/null; then
  exit 1
fi

NETWORK="$(ansible localhost -m setup -a "filter=ansible_default_ipv4" 2>/dev/null | grep "network" | awk '{print $NF}' | tr -d '",')/24"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
HOSTFILE="./hosts"

if [ -z "$NETWORK" ]; then
  echo "Missing network."
  exit 1
elif [ ! -r "$KNOWN_HOSTS" ]; then
  echo "Verify the $KNOWN_HOSTS file."
fi

if ! command -v vagrant 1>/dev/null; then
  exit 1
fi

if ! vagrant validate Vagrantfile; then
  exit 1
fi

if [ "$(vagrant status | grep -c 'running.*virtualbox')" -le 0 ]; then
  echo "No vagrant boxes are running. Exiting."
  exit 1
fi

echo "Generating Ansible hosts file."
echo "# $(date)" > "${HOSTFILE}"

{
  echo
  echo "[bastion]"
  for VM in $(vagrant status | grep -iE 'running.*virtualbox' | grep 'bastion' | awk '{print $1}'); do
    mapfile -t VAGRANT_SSH < <(vagrant ssh-config "$VM" | awk '{print $NF}')
    ANSIBLE_HOST_IP=$(vagrant ssh "$VM" -c "hostname -I | cut -f2 -d' '" | tr -d '\r' | sed 's/ //g')
    ANSIBLE_INTERNAL_HOST_IP=$(vagrant ssh "$VM" -c "hostname -I | cut -f3 -d' '" | tr -d '\r' | sed 's/ //g')
    mapfile -t VAGRANT_SSH < <(vagrant ssh-config "$VM" | awk '{print $NF}')
    echo "${VAGRANT_SSH[0]} ansible_host=${ANSIBLE_HOST_IP} ansible_user=${VAGRANT_SSH[2]} ansible_private_key_file=${VAGRANT_SSH[7]}"

    yes | ssh-keygen -R "${ANSIBLE_HOST_IP}" &>/dev/null
    ssh -i "${VAGRANT_SSH[7]}" "${VAGRANT_SSH[2]}@${ANSIBLE_HOST_IP}" 'echo "Host 10.2.*" >> ~/.ssh/config && "  StrictHostKeyChecking no" >> ~/.ssh/config'

    {
      echo "---"
      echo "ansible_python_interpreter: \"/usr/bin/python3\""
      echo "ansible_ssh_common_args: '-o ProxyCommand=\"ssh -W %h:%p ${VAGRANT_SSH[2]}@${ANSIBLE_HOST_IP}\"'"
      echo "sshd_admin_net: [${ANSIBLE_INTERNAL_HOST_IP}]"
      echo "sshd_allow_groups: \"vagrant sudo ubuntu\""
      echo "sshd_max_auth_tries: 15"
      echo "..."
    } > "./group_vars/internal.yml"

    {
      echo "---"
      echo "ansible_python_interpreter: \"/usr/bin/python3\""
      echo "ansible_ssh_common_args: '-o ForwardAgent=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no'"
      echo "sshd_admin_net: [${NETWORK}]"
      echo "sshd_allow_groups: \"vagrant sudo ubuntu\""
      echo "sshd_max_auth_tries: 15"
      echo "..."
    } > "./group_vars/bastion.yml"
  done
} >> "${HOSTFILE}"

{
  echo
  echo "[internal]"
  for VM in $(vagrant status | grep -iE 'running.*virtualbox' | grep -v 'bastion' | awk '{print $1}'); do
    mapfile -t VAGRANT_SSH < <(vagrant ssh-config "$VM" | awk '{print $NF}')
    ANSIBLE_HOST_IP=$(vagrant ssh "$VM" -c "hostname -I | cut -f2 -d' '" | tr -d '\r' | sed 's/ //g')
    echo "${VAGRANT_SSH[0]} ansible_host=${ANSIBLE_HOST_IP} ansible_user=${VAGRANT_SSH[2]} ansible_private_key_file=${VAGRANT_SSH[7]}"
  done
} >> "${HOSTFILE}"

host_details() {
  {
    echo
    echo "[${1}]"
    for VM in $(vagrant status | grep -iE 'running.*virtualbox' | grep "$1" | awk '{print $1}'); do
      mapfile -t VAGRANT_SSH < <(vagrant ssh-config "$VM" | awk '{print $NF}')
      ANSIBLE_HOST_IP=$(vagrant ssh "$VM" -c "hostname -I | cut -f2 -d' '" | tr -d '\r' | sed 's/ //g')
      echo "${VAGRANT_SSH[0]} ansible_host=${ANSIBLE_HOST_IP} ansible_user=${VAGRANT_SSH[2]} ansible_private_key_file=${VAGRANT_SSH[7]}"
    done
  } >> "${HOSTFILE}"
}

host_details loadbalancer
host_details webserver

ssh-add -l | grep '\.vagrant' | awk '{print $3".pub"}' | while read -r SSHPUB; do
  if [ -r "${SSHPUB}" ]; then
    ssh-add -d "${SSHPUB}"
  fi
done

grep 'private_key' "${HOSTFILE}" | sed 's/.*=//g' | sort | uniq | while read -r PRIVATE_KEY; do
  ssh-keygen -y -f "${PRIVATE_KEY}" > "${PRIVATE_KEY}.pub"
  ssh-add "${PRIVATE_KEY}"
done

if command -v dos2unix 2>/dev/null; then
  dos2unix "${HOSTFILE}"
fi

if ! find ./ -type f -name '*.y*ml' ! -name '.*' -print0 | \
  xargs -0 ansible-lint; then
    echo "ansible-lint failed."
    exit 1
fi

if ! find ./ -type f -name '*.y*ml' ! -name '.*' -print0 | \
  xargs -0 yamllint -d "{extends: default, rules: {line-length: {level: warning}}}"; then
    echo "yamllint failed."
    exit 1
fi
