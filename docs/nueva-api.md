# Guía: Desplegar una nueva API en el servidor EC2

## Prerequisitos

- Acceso SSH al servidor: `ssh -i infrastructure/03-container-backend/ec2-backend-dev.pem ec2-user@<elastic_ip>`
- Acceso al panel DNS de `alfredo-dominguez.dev`
- Repositorio de la nueva API en GitHub bajo `alfredo0607`
- La API Node.js **siempre debe escuchar en el puerto 3000** internamente

---

## Regla de puertos

| API                       | Subdominio                                      | `PORT` en `.env` | `host_port` en workflow |
| ------------------------- | ----------------------------------------------- | ---------------- | ----------------------- |
| content-distribution      | content-distribution.alfredo-dominguez.dev      | 3000             | 3000                    |
| services-resize-image-api | services-resize-image-api.alfredo-dominguez.dev | 3000             | 3001                    |
| nueva-api                 | nueva-api.alfredo-dominguez.dev                 | **3000**         | **3002**                |

> `PORT=3000` siempre dentro del contenedor. El puerto externo único lo define el workflow.

---

## Paso 1 — Registro DNS

En el panel de tu proveedor de dominio crea un registro tipo A:

| Campo  | Valor                        |
| ------ | ---------------------------- |
| Tipo   | `A`                          |
| Nombre | `nombre-nueva-api`           |
| Valor  | IP elástica del servidor EC2 |
| TTL    | 300                          |

Verifica que propagó antes de continuar:

```bash
nslookup nombre-nueva-api.alfredo-dominguez.dev
# Debe devolver la IP elástica del servidor
```

---

## Paso 2 — Registrar Nginx + SSL en el servidor

Conéctate al servidor:

```bash
ssh -i infrastructure/03-container-backend/ec2-backend-dev.pem ec2-user@<elastic_ip>
```

Ejecuta `add-api.sh` con el subdominio completo y el puerto host asignado:

```bash
~/add-api.sh nombre-nueva-api.alfredo-dominguez.dev 3002
```

Este script hace tres cosas:

1. Crea `/etc/nginx/conf.d/nombre-nueva-api.alfredo-dominguez.dev.conf`
2. Recarga Nginx
3. Emite el certificado SSL con Let's Encrypt y activa la redirección HTTP → HTTPS

---

## Paso 3 — Crear el archivo `.env` en el servidor

Dentro del servidor, crea el env file específico para esta API.
El nombre del archivo debe coincidir exactamente con el `container_name` del workflow:

```bash
nano ~/.env.nombre-nueva-api
```

Contenido mínimo:

```env
NODE_ENV=production
PORT=3000

# AWS
AWS_REGION=us-east-1
AWS_PUBLIC_KEY=<access-key-id>
AWS_PRIVATE_KEY=<secret-access-key>

# Variables específicas de esta API...
```

> **Importante:** `PORT=3000` siempre. El puerto externo (`3002`) lo maneja Docker, no la app.

---

## Paso 4 — Secrets en GitHub

En el nuevo repositorio → **Settings → Secrets and variables → Actions → New repository secret**

Agrega estos tres secretos (los mismos valores para todas las APIs):

| Secreto       | Valor                                                |
| ------------- | ---------------------------------------------------- |
| `EC2_HOST`    | IP elástica del servidor                             |
| `EC2_USER`    | `ec2-user`                                           |
| `EC2_SSH_KEY` | Contenido completo del archivo `ec2-backend-dev.pem` |

Para copiar el PEM en Windows:

```powershell
Get-Content infrastructure\03-container-backend\ec2-backend-dev.pem | clip
```

---

## Paso 5 — Crear el workflow en el nuevo repositorio

Crea el archivo `.github/workflows/deploy.yml` en el nuevo repo con estos valores ajustados:

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  deploy:
    uses: alfredo0607/aws-secure-content-distribution/.github/workflows/deploy-template.yml@main
    with:
      container_name: nombre-nueva-api # ← nombre único, debe coincidir con .env.<nombre>
      host_port: 3002 # ← puerto externo único para esta API
      build_context: . # ← ruta al Dockerfile desde la raíz del repo
    secrets:
      EC2_HOST: ${{ secrets.EC2_HOST }}
      EC2_USER: ${{ secrets.EC2_USER }}
      EC2_SSH_KEY: ${{ secrets.EC2_SSH_KEY }}
```

---

## Paso 6 — Push y verificación

Haz push a `main`. El pipeline:

1. Construye la imagen Docker para `linux/amd64` y `linux/arm64`
2. La sube a `ghcr.io/alfredo0607/<repo>:sha-<commit>`
3. Se conecta al servidor vía SSH y ejecuta `deploy.sh`

Cuando termine, verifica:

```bash
# En el servidor
docker ps                                                        # el contenedor debe aparecer como "Up"
curl -s http://localhost:3002/health                             # respuesta interna directa
curl -s https://nombre-nueva-api.alfredo-dominguez.dev/health   # respuesta pública con SSL
```

---

## Troubleshooting

### El contenedor no levanta

```bash
docker logs nombre-nueva-api --tail 50
```

Causa más común: el `.env.nombre-nueva-api` no existe o tiene `PORT` distinto de `3000`.

### Nginx devuelve 502

```bash
curl http://localhost:<host_port>/health
```

El contenedor no escucha en el puerto correcto. Verifica que `PORT=3000` en el env file y reinicia:

```bash
~/deploy.sh ghcr.io/alfredo0607/<repo>:latest nombre-nueva-api 3002
```

### Nginx no carga la config (server_names_hash)

```bash
sudo nginx -t
# Si falla: server_names_hash_bucket_size
sudo sed -i '/types_hash_max_size/a\    server_names_hash_bucket_size 128;' /etc/nginx/nginx.conf
sudo nginx -t && sudo systemctl reload nginx
```

### El DNS aún no propagó

```bash
nslookup nombre-nueva-api.alfredo-dominguez.dev 8.8.8.8
```

Espera hasta que devuelva la IP correcta antes de ejecutar `add-api.sh`.

### Ver todos los contenedores activos

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
```
