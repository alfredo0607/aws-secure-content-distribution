# AWS Secure Content Distribution — Frontend

Demo interactiva para la arquitectura de distribución de contenido privado en AWS. Permite subir archivos a S3, listar el contenido del bucket y generar **Signed URLs** de CloudFront con tiempo de expiración configurable.

> Desarrollado por **Alfredo Jose Dominguez Hernandez**
> [![LinkedIn](https://img.shields.io/badge/LinkedIn-alfredo--jose--dominguez--hernandez-0077B5?logo=linkedin)](https://www.linkedin.com/in/alfredo-jose-dominguez-hernandez)
> [![GitHub](https://img.shields.io/badge/GitHub-aws--secure--content--distribution-181717?logo=github)](https://github.com/alfredo0607/aws-secure-content-distribution)

---

## Stack

| Tecnología | Versión | Rol |
|-----------|---------|-----|
| [Astro](https://astro.build) | 6.x | Framework web (modo estático) |
| [Tailwind CSS](https://tailwindcss.com) | 4.x | Estilos utilitarios |
| Vanilla JavaScript | — | Lógica cliente (fetch, DOM) |
| Node.js | >= 22 | Runtime de desarrollo |
| pnpm | >= 11 | Package manager |

Sin frameworks de componentes (React/Vue). Toda la interactividad se maneja con JavaScript nativo en el cliente.

---

## Funcionalidades

- **Subida de archivos** — zona de drag & drop o selector de archivos. Validación de tamaño en cliente (máx. 10 MB).
- **Lista de archivos** — consulta el bucket S3 vía API y muestra nombre, tamaño y fecha de última modificación.
- **Signed URLs** — modal para generar una URL firmada de CloudFront con expiración configurable: 15 min, 1 h, 24 h o 7 días.
- **Eliminar archivos** — elimina objetos del bucket con confirmación.
- **Copiar URL** — copia la Signed URL al portapapeles con un clic.
- **Toast de feedback** — notificaciones de éxito y error con auto-dismiss.

---

## Requisitos previos

- Node.js >= 22
- pnpm >= 11 (`npm install -g pnpm`)
- Backend corriendo (ver [`../backend/readme.md`](../backend/readme.md))

---

## Instalación

```bash
cd frontend
pnpm install
```

---

## Configuración

Copia el archivo de ejemplo y ajusta la URL del backend:

```bash
cp .env.example .env
```

```env
# URL base del backend (sin trailing slash)
PUBLIC_API_URL=http://localhost:3000/api/v1
```

> Las variables con prefijo `PUBLIC_` son expuestas al cliente por Astro en tiempo de build.

### CORS

El backend debe aceptar peticiones desde el origen del frontend. En `backend/.env`:

```env
CORS_ORIGIN=http://localhost:4321
```

---

## Ejecución

```bash
# Desarrollo (hot reload en http://localhost:4321)
pnpm dev

# Build estático para producción
pnpm build

# Previsualizar el build
pnpm preview
```

---

## Estructura del proyecto

```
frontend/
├── src/
│   ├── layouts/
│   │   └── Layout.astro        # HTML base, dark theme
│   ├── pages/
│   │   └── index.astro         # Página principal + JS cliente
│   └── styles/
│       └── global.css          # @import "tailwindcss"
├── public/
│   └── favicon.svg
├── astro.config.mjs            # Tailwind v4 via @tailwindcss/vite
├── tsconfig.json
├── .env                        # Variables de entorno (no commitear)
├── .env.example                # Template
└── package.json
```

---

## Arquitectura cliente

Toda la UI es una Single Page estática (`index.astro`) con JavaScript inline. No hay routing ni estado global — cada operación es una llamada `fetch` directa al backend.

```
Browser
  │
  ├── GET    /api/v1/files                        → lista archivos
  ├── POST   /api/v1/files/upload                 → sube archivo (multipart/form-data)
  ├── GET    /api/v1/files/:key/signed-url?expires=N → genera Signed URL
  └── DELETE /api/v1/files/:key                   → elimina archivo
```

Las variables de entorno `PUBLIC_*` se inyectan en el HTML en build time vía `define:vars` de Astro — no requieren servidor en producción.

---

## Build y despliegue

El output es HTML/CSS/JS estático en `dist/`. Se puede servir desde cualquier CDN.

```bash
pnpm build
# → dist/
```

Para desplegar en S3 + CloudFront (mismo stack del proyecto):

```bash
aws s3 sync dist/ s3://<tu-bucket-frontend>/ --delete
aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"
```

---

## Scripts disponibles

| Comando | Descripción |
|---------|------------|
| `pnpm dev` | Servidor de desarrollo en `localhost:4321` |
| `pnpm build` | Genera el build estático en `./dist/` |
| `pnpm preview` | Previsualiza el build localmente |
| `pnpm astro check` | Verifica tipos y errores en archivos `.astro` |

---

## Autor

**Alfredo Jose Dominguez Hernandez**

- [LinkedIn](https://www.linkedin.com/in/alfredo-jose-dominguez-hernandez)
- [GitHub](https://github.com/alfredo0607)
- [Repositorio del proyecto](https://github.com/alfredo0607/aws-secure-content-distribution)
