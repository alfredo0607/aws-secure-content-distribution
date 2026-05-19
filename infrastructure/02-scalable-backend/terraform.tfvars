env = "dev"

# URL de la imagen ECR — completar después del paso 2 (docker push)
app_image = "578209355877.dkr.ecr.us-east-1.amazonaws.com/backend-dev:latest"

# Datos de la Arquitectura 01 (CDN) — obtener con: cd ../01-private-cdn && terraform output
aws_bucket_name   = "my-private-assets-dev-2026-demo"
cloudfront_domain = "https://d3njohe7p1rrbs.cloudfront.net"

# Frontend que consume la API
cors_origin = "http://localhost:4322"

# CloudFront key pair (Arquitectura 01)
cloudfront_keypair_id = "K1QOB35VVE3M52"

# Secretos — pasar por variable de entorno o archivo .tfvars local (nunca commitear)
jwt_secret             = "c1da77bb-9755-4d8c-80b1-611b3a31bec1"
jwt_refresh_secret     = "c1da77bb-9755-4d8c-80b1-611b3a31bec1"
cloudfront_private_key = "$(cat ../../backend/src/AWS/cloudfront/key/privkey.pem)"
