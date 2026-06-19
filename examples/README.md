# Ejemplo de uso de `mikroways.authkeysync`

Playbook mínimo que sincroniza las claves SSH del equipo de Mikroways en uno o
más recursos (bastiones o cualquier servidor), usando solo el rol
`mikroways.authkeysync`. A diferencia de un bastión "completo" del marco técnico
de conexión a clientes (que además aplica `mikroways.teleport` y
`mikroways.workstation`), acá **solo se instalan y mantienen las claves**.

El rol **no usa `become`**: se conecta con el usuario indicado en el inventario
y sincroniza el `authorized_keys` de ese usuario. Crear la cuenta es un paso
previo (cloud-init, Terraform, etc.).

## Uso

```bash
# Instalar el rol
ansible-galaxy install -r requirements.yml

# Editar inventory.ini con los hosts y el usuario de conexión reales
ansible-playbook -i inventory.ini playbook.yml
```

## Probar en una VM con Vagrant

El subdirectorio [`vagrant/`](vagrant/) levanta una VM Ubuntu (box
`ubuntu/jammy64`) y le aplica el rol, sin tocar ningún servidor real:

```bash
cd vagrant
vagrant up      # crea la VM y le aplica el rol sobre el usuario "vagrant"
vagrant ssh     # entrar a la VM para verificar (ver abajo)
```

Ya dentro de la VM, comprobar que el rol dejó todo en su lugar:

```bash
# 1. El binario quedó instalado en el HOME del usuario (sin root)
~/.local/bin/authkeysync --version

# 2. La configuración apunta al usuario y a la fuente de claves del equipo
cat ~/.config/authkeysync/config.yaml

# 3. Hay un cron del usuario que re-sincroniza cada 5 minutos
crontab -l

# 4. El authorized_keys quedó poblado con las claves del equipo de Mikroways
cat ~/.ssh/authorized_keys

# 5. (opcional) Probar que una sincronización manual no rompe nada y es idempotente
~/.local/bin/authkeysync --config ~/.config/authkeysync/config.yaml
```

Para ver el modo estricto en acción (el rol borra claves que no están en la
fuente), agregar una clave de prueba y volver a sincronizar: desaparece.
Ojo que en este ejemplo se usa `preserve_local_keys: true`, así que **no** se
borra; cambiá esa variable a `false` en `playbook.yml` y reprovisioná
(`vagrant provision`) para probar el borrado.

Salir de la VM y borrarla al terminar:

```bash
exit
vagrant destroy -f
```

Requiere Vagrant + VirtualBox y que `ansible-playbook` esté en el PATH (lo
provee el `direnv allow` del repo). En la VM de prueba se usa
`preserve_local_keys: true` para no borrar la clave con la que Vagrant se
conecta; en un bastión real va en `false` (modo estricto).

## Archivos

| Archivo | Propósito |
|---------|-----------|
| `playbook.yml` | Aplica `mikroways.authkeysync` (incluye variante con claves del cliente) |
| `inventory.ini` | Inventario de ejemplo (bastiones y recursos) |
| `requirements.yml` | Declara el rol para `ansible-galaxy install` |
| `vagrant/` | Entorno de prueba con Vagrant (VM Ubuntu + provisión del rol) |
