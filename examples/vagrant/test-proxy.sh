#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$SCRIPT_DIR"

echo "=== Levantando VM ==="
vagrant up

VAGRANT_PORT=$(vagrant ssh-config | grep '  Port ' | awk '{print $2}')
VAGRANT_KEY=$(vagrant ssh-config | grep IdentityFile | awk '{print $2}')
SSH="ssh -i $VAGRANT_KEY -p $VAGRANT_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@127.0.0.1"

echo "=== Eliminando binario previo para forzar descarga por proxy ==="
$SSH "rm -f ~/.local/bin/authkeysync"

echo "=== Corriendo playbook con proxy (tinyproxy en 127.0.0.1:8888) ==="
ANSIBLE_HOST_KEY_CHECKING=False \
uv run --directory "$REPO_DIR" \
  ansible-playbook -i "127.0.0.1," \
  -e "ansible_port=$VAGRANT_PORT ansible_user=vagrant ansible_ssh_private_key_file=$VAGRANT_KEY" \
  -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" \
  "$SCRIPT_DIR/playbook-proxy.yml"

echo "=== Verificando ==="

echo "--- Binario instalado ---"
$SSH "~/.local/bin/authkeysync --version"

echo "--- Crontab con vars de proxy ---"
$SSH "crontab -l"

echo "--- authorized_keys no vacío ---"
COUNT=$($SSH "grep -c . ~/.ssh/authorized_keys")
if [ "$COUNT" -gt 0 ]; then
  echo "OK: $COUNT claves sincronizadas"
else
  echo "FAIL: authorized_keys vacío"
  exit 1
fi

echo "--- http_proxy en crontab ---"
$SSH "crontab -l | grep -q 'http_proxy' && echo OK || (echo FAIL; exit 1)"

echo "--- https_proxy en crontab ---"
$SSH "crontab -l | grep -q 'https_proxy' && echo OK || (echo FAIL; exit 1)"

echo "=== Test proxy completo ==="
