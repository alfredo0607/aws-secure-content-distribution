# AWS Secure Content Distribution — Backend

API REST construida con **Node.js + Express 5** que gestiona la subida de archivos a un bucket S3 privado y la generación de **Signed URLs de CloudFront** con expiración configurable. El bucket nunca es accesible públicamente; todo el acceso pasa por CloudFront usando Origin Access Control (OAC) con firma SigV4.

> Desarrollado por **Alfredo Jose Dominguez Hernandez**
> [![LinkedIn](https://img.shields.io/badge/LinkedIn-alfredo--jose--dominguez--hernandez-0077B5?logo=linkedin)](https://www.linkedin.com/in/alfredo-jose-dominguez-hernandez)
> [![GitHub](https://img.shields.io/badge/GitHub-aws--secure--content--distribution-181717?logo=github)](https://github.com/alfredo0607/aws-secure-content-distribution)

---

## Stack

| Tecnología | Versión | Rol |
|-----------|---------|-----|
| Node.js | >= 20 | Runtime |
| Express | 5.2.1 | Framework HTTP |
| ES Modules | — | Sistema de módulos |
| pnpm | 11.1.2 | Package manager |
| AWS SDK v3 | 3.1048.0 | Cliente S3 y CloudFront |
| sharp | 0.34.5 | Compresión de imágenes |
| express-fileupload | 1.5.2 | Parsing de multipart/form-data |
| helmet | 8.1.0 | Headers HTTP de seguridad |
| express-rate-limit | 8.5.2 | Rate limiting por IP |
| morgan | 1.10.1 | Logger HTTP |
| nanoid | 5.1.11 | Generación de nombres únicos |

---

## Estructura del proyecto

```
backend/
├── src/
│   ├── AWS/
│   │   ├── S3/
│   │   │   └── index.js            # PutObject, ListObjectsV2, DeleteObject
│   │   └── cloudfront/
│   │       ├── index.js            # Firma de Signed URLs (SigV4)
│   │       └── key/
│   │           ├── privkey.pem     # Clave privada CloudFront (no commitear)
│   │           └── pubkey.pem      # Clave pública CloudFront
│   ├── config/
│   │   └── app.js                  # Configuración centralizada de la app
│   ├── controllers/
│   │   └── files.controller.js     # Request/response + validaciones
│   ├── helpers/
│   │   ├── uploadFile.helper.js    # Compresión de imágenes + orquestación
│   │   └── codeGenerator.helper.js # Generadores de IDs, códigos y OTPs
│   ├── middlewares/
│   │   └── errorHandler.js         # AppError, handler global, 404
│   ├── routes/
│   │   ├── index.js                # GET / y GET /health
│   │   └── files.router.js         # CRUD de archivos
│   ├── services/
│   │   └── files.service.js        # Lógica de negocio (S3 + CloudFront)
│   ├── app.js                      # Setup Express (middlewares, rutas)
│   └── server.js                   # Entry point + graceful shutdown
├── config.js                       # Variables AWS exportadas desde process.env
├── .env.example                    # Template de variables de entorno
├── eslint.config.js
├── .prettierrc
└── package.json
```

---

## Requisitos previos

- **Node.js** >= 20
- **pnpm** >= 11 (`npm install -g pnpm`)
- **Cuenta AWS** con los siguientes recursos creados (ver [`../infrastructure/`](../infrastructure/)):
  - Bucket S3 privado con `BlockPublicAccess` habilitado
  - Distribución CloudFront con OAC y Trusted Key Group
  - KMS Key para cifrado SSE-KMS del bucket
- **Par de claves CloudFront** (Key Pair) generado en AWS Console → CloudFront → Key management

---

## Configuración del entorno

```bash
cp .env.example .env
```

### Variables de entorno

| Variable | Requerida | Descripción | Ejemplo |
|----------|-----------|-------------|---------|
| `NODE_ENV` | No | Entorno de ejecución | `development` |
| `PORT` | No | Puerto del servidor (default: 3000) | `3000` |
| `API_PREFIX` | No | Prefijo de rutas (default: /api/v1) | `/api/v1` |
| `CORS_ORIGIN` | Sí | Origen permitido por CORS | `http://localhost:4321` |
| `AWS_REGION` | Sí | Región de AWS | `us-east-1` |
| `AWS_PUBLIC_KEY` | Sí | Access Key ID de IAM | `AKIA...` |
| `AWS_PRIVATE_KEY` | Sí | Secret Access Key de IAM | `wJalrX...` |
| `AWS_BUCKET_NAME` | Sí | Nombre del bucket S3 | `my-private-assets-dev-2026` |
| `CLOUDFRONT_KEYPAIR_ID` | Sí | ID del Key Pair de CloudFront | `K1QOB35VVE3M52` |
| `CLOUDFRONT_PRIVATE_KEY` | Sí | Ruta absoluta al archivo `privkey.pem` | `/app/src/AWS/cloudfront/key/privkey.pem` |
| `CLOUDFRONT_DOMAIN` | Sí | Dominio de la distribución CloudFront | `https://xxxx.cloudfront.net` |
| `RATE_LIMIT_WINDOW_MS` | No | Ventana de rate limiting en ms (default: 900000) | `900000` |
| `RATE_LIMIT_MAX` | No | Máximo de requests por ventana (default: 100) | `100` |
| `LOG_LEVEL` | No | Nivel de log de Morgan | `dev` |

### Clave privada de CloudFront

Coloca el par de claves en `src/AWS/cloudfront/key/`. Estas claves se obtienen desde la consola de AWS:

```
src/AWS/cloudfront/key/
├── privkey.pem   ← clave privada (NUNCA commitear)
└── pubkey.pem    ← clave pública (subida a AWS CloudFront Key management)
```

> En producción usa **AWS Secrets Manager** para almacenar `privkey.pem` en lugar de un archivo en disco.

---

## Instalación y ejecución

```bash
cd backend

# Instalar dependencias
pnpm install

# Desarrollo (hot reload con nodemon)
pnpm dev

# Producción
pnpm prod
```

El servidor levanta en `http://localhost:3000` e imprime:

```
══════════════════════════════════════════════
  Aws Secure Content Distribution — API
  Environment : development
  Node        : v20.x.x
══════════════════════════════════════════════

[SERVER] ✅  Listening on http://localhost:3000
[SERVER]     API prefix : /api/v1
[SERVER]     Health     : http://localhost:3000/health
```

---

## API Reference

Base URL: `http://localhost:3000`

### Sistema

#### `GET /health`

Health check. Útil para load balancers y probes de contenedor.

**Respuesta 200:**
```json
{
  "message": "All systems operational",
  "data": {
    "status": "ok",
    "env": "development",
    "uptime": "42s",
    "memory": "48 MB",
    "time": "2026-05-18T14:00:00.000Z"
  }
}
```

#### `GET /`

Información de la API.

**Respuesta 200:**
```json
{
  "message": "Aws Secure Content Distribution API",
  "data": {
    "version": "1.0.0",
    "prefix": "/api/v1",
    "docs": "/api/v1/docs",
    "health": "/health"
  }
}
```

---

### Archivos — `/api/v1/files`

#### `POST /api/v1/files/upload`

Sube un archivo al bucket S3. Las imágenes se comprimen automáticamente con **sharp** antes de subirse.

**Content-Type:** `multipart/form-data`

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `file` | File | Sí | Archivo a subir (máx. 10 MB) |

**Respuesta 201:**
```json
{
  "message": "File uploaded successfully",
  "data": {
    "key": "V1StGXR8_Z5jdHi6Babc123def456.jpg"
  }
}
```

**Compresión automática de imágenes:**

| Tamaño del archivo | Calidad JPEG aplicada |
|-------------------|-----------------------|
| >= 2 MB | 30 % |
| 1 MB – 2 MB | 60 % |
| < 1 MB | 100 % (sin pérdida) |

---

#### `GET /api/v1/files`

Lista todos los archivos del bucket en el folder `uploads/`.

**Respuesta 200:**
```json
{
  "message": "Files retrieved",
  "data": [
    {
      "key": "V1StGXR8_Z5jdHi6Babc123def456.jpg",
      "size": 204800,
      "lastModified": "2026-05-18T14:00:00.000Z"
    }
  ]
}
```

---

#### `GET /api/v1/files/:key/signed-url`

Genera una **Signed URL de CloudFront** para acceso temporal al archivo. La URL está firmada con la clave privada del Key Pair y expira en el tiempo indicado.

**Query params:**

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `expires` | number | `86400` | Tiempo de expiración en segundos |

**Ejemplos:**
```
GET /api/v1/files/abc123.jpg/signed-url             → expira en 24 h
GET /api/v1/files/abc123.jpg/signed-url?expires=900  → expira en 15 min
GET /api/v1/files/abc123.jpg/signed-url?expires=3600 → expira en 1 h
```

**Respuesta 200:**
```json
{
  "message": "Signed URL generated",
  "data": {
    "signedUrl": "https://xxxx.cloudfront.net/uploads/abc123.jpg?Policy=...&Signature=...&Key-Pair-Id=...",
    "expiresIn": 86400
  }
}
```

---

#### `DELETE /api/v1/files/:key`

Elimina un archivo del bucket S3.

**Respuesta 200:**
```json
{
  "message": "File deleted successfully"
}
```

---

### Formato de errores

Todos los errores siguen el mismo formato:

```json
{
  "success": false,
  "error": {
    "code": "FILE_MISSING",
    "message": "No file attached. Use field name \"file\".",
    "details": null
  }
}
```

| Código | Status | Descripción |
|--------|--------|-------------|
| `FILE_MISSING` | 400 | No se adjuntó ningún archivo |
| `INVALID_PARAM` | 400 | Parámetro `expires` inválido |
| `ROUTE_NOT_FOUND` | 404 | Ruta no encontrada |
| `UPLOAD_FAILED` | 500 | Error al subir a S3 |
| `LIST_FAILED` | 500 | Error al listar el bucket |
| `DELETE_FAILED` | 500 | Error al eliminar el objeto |
| `CONFIG_ERROR` | 500 | Variable de entorno no configurada |
| `RATE_LIMIT_EXCEEDED` | 429 | Demasiadas peticiones |

---

## Módulos AWS

### S3 (`src/AWS/S3/index.js`)

| Función | Descripción |
|---------|------------|
| `uploadFileS3(folder, fileName, file)` | Sube un objeto con `PutObjectCommand`. Fuerza `ContentDisposition: inline` para imágenes y PDFs. |
| `listFilesS3(prefix)` | Lista objetos con `ListObjectsV2Command` filtrando por prefijo. |
| `deleteFileS3(key)` | Elimina un objeto con `DeleteObjectCommand`. |

### CloudFront (`src/AWS/cloudfront/index.js`)

| Función | Descripción |
|---------|------------|
| `firmarUrl(url, expiresInSeconds)` | Genera una Signed URL usando `@aws-sdk/cloudfront-signer`. Firma con la clave privada del Key Pair. Expiración por defecto: 24 h. |

---

## Seguridad

- **S3 privado** — `BlockPublicAccess: true` en todas las ACLs. El bucket solo acepta peticiones de CloudFront vía política de bucket (OAC).
- **OAC + SigV4** — CloudFront firma cada request a S3 con SigV4. S3 rechaza cualquier petición no firmada por CloudFront.
- **Signed URLs** — el acceso de usuarios finales es siempre temporal. La clave privada firma la URL; CloudFront verifica la firma antes de servir el contenido.
- **SSE-KMS** — los objetos en S3 se cifran en reposo con una clave KMS dedicada con rotación automática.
- **Helmet** — headers HTTP de seguridad en todas las respuestas (`X-Frame-Options`, `CSP`, `HSTS`, etc.).
- **Rate limiting** — 100 requests por ventana de 15 min por IP. Configurable vía `.env`.
- **CORS estricto** — solo acepta el origen configurado en `CORS_ORIGIN`.

### Permisos IAM mínimos requeridos

El usuario IAM que usa el backend solo necesita:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GetObject",
    "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::my-private-assets-*",
    "arn:aws:s3:::my-private-assets-*/*"
  ]
}
```

---

## Scripts disponibles

| Comando | Descripción |
|---------|------------|
| `pnpm dev` | Servidor de desarrollo con nodemon (hot reload) |
| `pnpm start` | Servidor en modo producción |
| `pnpm prod` | Producción con `NODE_ENV=production` explícito |
| `pnpm lint` | Verifica reglas ESLint |
| `pnpm lint:fix` | Corrige errores ESLint automáticamente |
| `pnpm format` | Formatea código con Prettier |
| `pnpm format:check` | Verifica el formato sin escribir cambios |
| `pnpm test` | Ejecuta tests con Node test runner |
| `pnpm clean` | Elimina `node_modules` |

---

## Autor

**Alfredo Jose Dominguez Hernandez**

- [LinkedIn](https://www.linkedin.com/in/alfredo-jose-dominguez-hernandez)
- [GitHub](https://github.com/alfredo0607)
- [Repositorio del proyecto](https://github.com/alfredo0607/aws-secure-content-distribution)
