# PENDING

## Renovate: warning de vulnerability alerts

El Dependency Dashboard muestra:

> ⚠️ WARN: Cannot access vulnerability alerts. Please ensure permissions have been granted.

Dependadog alerts está habilitado en el repo pero la **GitHub App de Renovate de la org**
no tiene el permiso `vulnerability_alerts`. Christian (admin) debe agregarlo en la
configuración de la app (GitHub → Org settings → GitHub Apps → Renovate → Permissions →
agregar `vulnerability_alerts: read`).

## Repos que usan el formato viejo de requirements.yml

Actualizar `requirements.yml` para usar formato Galaxy (sin `src`/`scm`):

- ~~`mw-grant-ssh-access`~~ ✓ (actualizado a 0.2.1, tag 3.1.0)
- `harbor-ansible-role` (Banco Columbia) ← en curso
- skeleton de `mw-create-project`

## molecule-plugins bug

Cuando se publique molecule-plugins#364, eliminar:
- `molecule/default/create.yml`
- `molecule/proxy/create.yml`

Trackeado en GitHub issue #8.
