# Ejemplo de uso de `mikroways.authkeysync`

Playbook mínimo que sincroniza las claves SSH del equipo de Mikroways en uno o
más recursos (bastiones o cualquier servidor), usando solo el rol
`mikroways.authkeysync`. A diferencia de un bastión "completo" del marco técnico
de conexión a clientes (que además aplica `mikroways.teleport` y
`mikroways.workstation`), acá **solo se instalan y mantienen las claves**.

## Uso

```bash
# Instalar el rol
ansible-galaxy install -r requirements.yml

# Editar inventory.ini con los hosts y el usuario de conexión reales
ansible-playbook -i inventory.ini playbook.yml
```

## Probar en una VM con Vagrant

Requiere Vagrant + VirtualBox y que `ansible-playbook` esté en el PATH (lo
provee el `direnv allow` del repo). El subdirectorio [`vagrant/`](vagrant/)
levanta una VM Ubuntu (box `ubuntu/jammy64`) y le aplica el rol, sin tocar
ningún servidor real.

> A diferencia del uso de arriba (que instala el rol publicado desde un tag),
> esta prueba usa el **código local** del repo: `vagrant/roles/mikroways.authkeysync`
> es un symlink al rol, así probás tus cambios sin publicar una versión. Por eso
> ese symlink está versionado (no se gitignorea).

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

En la VM se usa `preserve_local_keys: true` para no borrar la clave con la que
Vagrant se conecta (en un bastión real va en `false`, modo estricto). Para ver
el borrado en acción, poné esa variable en `false` en `playbook.yml`, agregá una
clave de prueba al `authorized_keys` y reprovisioná (`vagrant provision`): en la
sincronización desaparece.

Salir de la VM y borrarla al terminar:

```bash
exit
vagrant destroy -f
```

### Probar el escenario con proxy

Para verificar que el rol funciona correctamente detrás de un proxy HTTP, hay un
script que levanta la VM, elimina el binario instalado para forzar la descarga
a través del proxy, y valida el resultado:

```bash
bash examples/vagrant/test-proxy.sh
```

Requiere que la VM ya esté corriendo (`vagrant up`) y que `uv` esté disponible.

### Alternativa: probar contra el rol publicado (galaxy)

Por defecto la prueba usa el código local (symlink). Para verificar lo que
recibe un consumidor —el rol publicado en el tag— correr con `FROM_GALAXY=1`:

```bash
FROM_GALAXY=1 vagrant up
```

En ese modo Vagrant ejecuta `ansible-galaxy install` desde `../requirements.yml`
(pinneado a la versión `0.2.1`), instala el rol en `.galaxy-roles/` (gitignoreado) y
provisiona con esa versión en lugar del código local. Requiere acceso a Ansible Galaxy.

> **Nota:** al provisionar, Vagrant pasa `--inventory-file` a `ansible-playbook` en lugar del
> flag actual `-i`. Esto genera un `[DEPRECATION WARNING]` que es inofensivo en las versiones
> actuales de ansible-core, pero se romperá en ansible-core 2.23. Es un bug de Vagrant
> ([vagrant/vagrant#13502](https://github.com/hashicorp/vagrant/issues/13502)) que requiere
> una actualización del provisioner de Vagrant para resolverse.
