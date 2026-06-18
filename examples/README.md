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

## Archivos

| Archivo | Propósito |
|---------|-----------|
| `playbook.yml` | Aplica `mikroways.authkeysync` (incluye variante con claves del cliente) |
| `inventory.ini` | Inventario de ejemplo (bastiones y recursos) |
| `requirements.yml` | Declara el rol para `ansible-galaxy install` |
