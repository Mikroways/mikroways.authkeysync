# Role mikroways.authkeysync

Instala y configura [AuthKeySync](https://github.com/eduardolat/authkeysync)
para mantener el `authorized_keys` de un usuario sincronizado automáticamente
desde una o más fuentes remotas de claves públicas, sin re-ejecutar el playbook
ante altas o bajas.

Reemplaza la gestión manual de claves del rol
[`mw-user`](https://github.com/Mikroways/mw-user) (deprecado).

## Alcance

Este rol **solo pone y mantiene claves** en el usuario con el que corre. No crea
usuarios: crear la cuenta es un paso previo (por ejemplo, cloud-init inyecta una
clave inicial y luego se corre este rol).

**El rol no usa `become`.** Se conecta directamente como el usuario destino, por
lo que no importa con qué usuario corre: siempre instala en su HOME. Para
sincronizar varios usuarios en un host, se aplica el rol una vez por usuario
(cada quien con su conexión).

## Cómo funciona

1. Descarga el binario de AuthKeySync desde GitHub releases a `~/.local/bin`.
2. Despliega `~/.config/authkeysync/config.yaml` con la política y las fuentes.
3. Asegura que `~/.ssh` exista (AuthKeySync omite al usuario si no existe).
4. Registra un cron en el crontab del usuario cada `authkeysync_cron_minute`.
5. Corre una sincronización inicial al aplicar el rol.

## Eliminación de claves (modo estricto)

Por defecto `authkeysync_preserve_local_keys` es **`false`**: el
`authorized_keys` queda **exactamente igual a la fuente**. Si una persona deja
Mikroways y su clave se quita del repositorio de claves, también se elimina del
`authorized_keys` en la siguiente sincronización.

> **Cuidado con el lockout.** AuthKeySync no usa marcadores: en modo estricto
> cualquier clave local que no esté en una fuente se borra (incluida la clave
> inicial que pudo inyectar cloud-init, si no está publicada en la fuente).
> Asegurarse de que la fuente contenga toda clave legítima o contar con un
> camino de acceso alternativo (consola del proveedor, Teleport, etc.). Los
> backups quedan activos (`backup_enabled: true`).
>
> Si se necesita preservar claves agregadas manualmente, poner
> `authkeysync_preserve_local_keys: true`.

## Variables

| Variable | Default | Descripción |
|----------|---------|-------------|
| `authkeysync_version` | `v0.1.1` | Versión del binario a instalar (un tag de release, ej. `v0.1.1`, o `latest`). |
| `authkeysync_arch` | `amd64` | Arquitectura del binario (`amd64` \| `arm64`). |
| `authkeysync_bin_dir` | `~/.local/bin` | Directorio del binario. |
| `authkeysync_config_dir` | `~/.config/authkeysync` | Directorio de configuración. |
| `authkeysync_backup_enabled` | `true` | Crear backup antes de modificar `authorized_keys`. |
| `authkeysync_backup_retention_count` | `10` | Cantidad de backups a conservar. |
| `authkeysync_preserve_local_keys` | `false` | `false` = estricto (elimina claves ausentes en la fuente). |
| `authkeysync_cron_minute` | `*/5` | Frecuencia del cron de sincronización. |
| `authkeysync_run_initial_sync` | `true` | Correr una sincronización inicial al aplicar el rol. |
| `authkeysync_http_proxy` | `""` | Proxy HTTP para descargar el binario y para el cron de sincronización. Vacío = sin proxy. |
| `authkeysync_https_proxy` | `""` | Proxy HTTPS ídem. |
| `authkeysync_no_proxy` | `""` | Lista de hosts excluidos del proxy (ej. `localhost,10.0.0.0/8`). |
| `authkeysync_ssh_dir` | `~/.ssh` | Directorio SSH del usuario. Útil cuando se corre con `become: true` y el HOME resuelve a `/root/.ssh`. |
| `authkeysync_mikroways_keys_url` | `https://mikroways.gitlab.io/public/ssh_keys/_all.pub` | Fuente de claves del equipo de Mikroways. |
| `authkeysync_username` | usuario que corre el rol | Usuario destino del `authorized_keys`. |
| `authkeysync_sources` | claves del equipo Mikroways | Lista de fuentes de claves a sincronizar. |

Las variables de proxy cubren dos momentos: la descarga del binario durante el
`ansible-playbook` y las sincronizaciones del cron en runtime (las variables
quedan inyectadas en el crontab del usuario).

### Estructura de `authkeysync_sources`

```yaml
authkeysync_sources:
  - url: "https://mikroways.gitlab.io/public/ssh_keys/_all.pub"
  - url: "https://claves-del-cliente.example/equipo.pub"
```

Cada fuente admite además `method` y `timeout_seconds` (ver la
[documentación de AuthKeySync](https://eduardolat.github.io/authkeysync/configuration/)).

## Ejemplo

`requirements.yml` del proyecto:

```yaml
roles:
  - name: mikroways.authkeysync
    version: "0.2.1"
```

Playbook:

```yaml
- name: Sincronizar claves del equipo en el bastión
  hosts: all
  become: false
  gather_facts: true
  roles:
    - role: mikroways.authkeysync
```

En [`examples/`](examples/) hay un ejemplo completo (playbook + inventario +
`requirements.yml`) y, en [`examples/vagrant/`](examples/vagrant/), un entorno
de prueba con Vagrant para aplicar el rol sobre una VM real.
Ver [`examples/README.md`](examples/README.md) para detalles.

## Migración desde mw-user

`mw-user` creaba el usuario `mikroways`, configuraba sudo sin contraseña y
sincronizaba las claves del equipo, todo en un solo rol con `become: true`.
`mikroways.authkeysync` hace **solo** la sincronización de claves: la creación
del usuario y la configuración de sudo son responsabilidad del llamador
(cloud-init, Terraform, otro rol).

### requirements.yml

Antes:

```yaml
roles:
  - role: mikroways.mw_user
```

Ahora:

```yaml
roles:
  - name: mikroways.authkeysync
    version: "0.2.1"
```

### Playbook

Si ya tenés acceso SSH como el usuario al que querés sincronizar claves
(p.ej. un bastión donde conectás como `mikroways`), el rol corre sin `become`
y resuelve todos los paths desde el HOME del usuario de conexión:

```yaml
- name: Sincronizar claves
  hosts: all
  become: false
  gather_facts: true
  roles:
    - role: mikroways.authkeysync
```

Cuando hay que crear el usuario primero (equivalente directo de `mw-user`),
se conecta como un usuario con privilegios, se crean el usuario y el sudoers
con tasks explícitas, y luego se aplica el rol con `become_user`. En este caso
`ansible_env.HOME` resuelve al home del usuario privilegiado, por lo que hay
que indicar los paths explícitamente:

```yaml
- name: Crear usuario y sincronizar claves
  hosts: all
  gather_facts: true
  vars:
    mw_user_name: mikroways
  tasks:
    - name: Crear usuario
      ansible.builtin.user:
        name: "{{ mw_user_name }}"
        shell: /bin/bash
        state: present
      become: true

    - name: Configurar sudo sin contraseña
      ansible.builtin.copy:
        content: "{{ mw_user_name }} ALL=(ALL) NOPASSWD:ALL\n"
        dest: "/etc/sudoers.d/{{ mw_user_name }}"
        mode: "0440"
        validate: visudo -cf %s
      become: true

    - name: Sincronizar claves SSH
      ansible.builtin.include_role:
        name: mikroways.authkeysync
      become: true
      become_user: "{{ mw_user_name }}"
      vars:
        authkeysync_bin_dir: "/home/{{ mw_user_name }}/.local/bin"
        authkeysync_config_dir: "/home/{{ mw_user_name }}/.config/authkeysync"
        authkeysync_ssh_dir: "/home/{{ mw_user_name }}/.ssh"
        authkeysync_username: "{{ mw_user_name }}"
        authkeysync_preserve_local_keys: true
```

### Variables equivalentes

| mw-user | mikroways.authkeysync |
|---------|----------------------|
| `mw_user_keys_url` | `authkeysync_mikroways_keys_url` |
| `mw_user_customer_users[].keys_url` | `authkeysync_sources` (lista de URLs) |

La variable `authkeysync_preserve_local_keys: true` es el equivalente al
comportamiento anterior donde las claves locales preexistentes no se tocaban.

## Desarrollo

El entorno (Ansible, molecule) se gestiona con [uv](https://docs.astral.sh/uv/)
y se activa solo con [direnv](https://direnv.net/):

```bash
direnv allow   # crea el venv con uv (si falta) y lo activa al entrar al repo
```

Sin direnv, el equivalente es `uv sync` y prefijar los comandos con `uv run`.

Las pruebas usan [molecule](https://molecule.readthedocs.io/) con Docker:

```bash
molecule converge   # crea los contenedores y aplica el rol
molecule verify     # verifica que el rol hizo lo esperado
molecule destroy    # destruye los contenedores
molecule test       # ciclo completo (escenario default)
molecule test -s proxy  # ciclo completo con tinyproxy
```
