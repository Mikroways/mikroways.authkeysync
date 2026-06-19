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

**El rol no usa `become`.** Se instala a nivel del usuario:

- binario en `~/.local/bin/authkeysync`
- configuración en `~/.config/authkeysync/config.yaml`
- un cron en el crontab del propio usuario, cada 5 minutos
- sincroniza el `~/.ssh/authorized_keys` de ese usuario

Por eso no importa con qué usuario se ejecute: sincroniza las claves de ese
usuario. Para sincronizar varios usuarios en un host, se aplica el rol una vez
por usuario (cada quien con su conexión).

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
| `authkeysync_version` | `latest` | Versión a instalar (`latest` o tag de release, ej. `v0.1.1`). |
| `authkeysync_arch` | `amd64` | Arquitectura del binario (`amd64` \| `arm64`). |
| `authkeysync_bin_dir` | `~/.local/bin` | Directorio del binario. |
| `authkeysync_config_dir` | `~/.config/authkeysync` | Directorio de configuración. |
| `authkeysync_backup_enabled` | `true` | Crear backup antes de modificar `authorized_keys`. |
| `authkeysync_backup_retention_count` | `10` | Cantidad de backups a conservar. |
| `authkeysync_preserve_local_keys` | `false` | `false` = estricto (elimina claves ausentes en la fuente). |
| `authkeysync_cron_minute` | `*/5` | Frecuencia del cron de sincronización. |
| `authkeysync_run_initial_sync` | `true` | Correr una sincronización inicial al aplicar el rol. |
| `authkeysync_mikroways_keys_url` | `https://mikroways.gitlab.io/public/ssh_keys/_all.pub` | Fuente de claves del equipo de Mikroways. |
| `authkeysync_username` | usuario que corre el rol | Usuario destino del `authorized_keys`. |
| `authkeysync_sources` | claves del equipo Mikroways | Lista de fuentes de claves a sincronizar. |

### Estructura de `authkeysync_sources`

```yaml
authkeysync_sources:
  - url: "https://mikroways.gitlab.io/public/ssh_keys/_all.pub"
  - url: "https://claves-del-cliente.example/equipo.pub"
```

Cada fuente admite además `method` y `timeout_seconds` (ver la documentación de
AuthKeySync).

## Ejemplo

`requirements.yml` del proyecto:

```yaml
roles:
  - name: mikroways.authkeysync
    src: git@github.com:Mikroways/mikroways.authkeysync.git
    scm: git
    version: main
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
Ver `examples/README.md` para detalles.

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
molecule test       # ciclo completo
```
