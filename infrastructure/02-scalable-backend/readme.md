# Arquitectura 02 — Backend Escalable con Contenedores

## Problema

Escalar APIs modernas de forma automática ante picos de tráfico sin intervención manual ni gestión de servidores.

## Solución

ECS Fargate + Application Load Balancer + Auto Scaling con rolling deployments y observabilidad via CloudWatch.

## Diagrama

```
Internet
  │
  ▼
Route 53
  │
  ▼
Application Load Balancer
  │        │
  ▼        ▼
ECS Task  ECS Task  (Fargate — autoscaling)
  │
  ▼
RDS PostgreSQL (Multi-AZ)
  │
  ▼
CloudWatch (métricas + logs + alarms)
```

> Diagrama detallado: `diagram.png` (pendiente)

## Servicios AWS

| Servicio                  | Rol                                      |
| ------------------------- | ---------------------------------------- |
| ECS Fargate               | Orquestación serverless de contenedores  |
| Application Load Balancer | Distribución de tráfico L7               |
| Auto Scaling              | Escalado basado en CPU/mem/request count |
| RDS PostgreSQL            | Base de datos relacional administrada    |
| ECR                       | Registro privado de imágenes Docker      |
| CloudWatch                | Métricas, logs, alarms y dashboards      |
| Secrets Manager           | Credenciales DB y API keys               |
| VPC + Security Groups     | Aislamiento de red                       |

## Decisiones Técnicas

- [ADR-002: ECS Fargate en lugar de EC2](../../docs/decisions/ADR-002-ecs-fargate-vs-ec2.md)

## Consideraciones

### Seguridad

- Tareas Fargate en subredes privadas (sin IP pública directa)
- IAM Task Roles con permisos mínimos
- RDS en subnet group privado, sin endpoint público
- Secrets en Secrets Manager, inyectados como env vars al task

### Costo

- Fargate: ~$0.04048/vCPU-hora + $0.004445/GB-hora
- ALB: ~$0.008/hora + $0.008/LCU-hora
- RDS db.t3.micro: ~$0.017/hora (single-AZ para demo)

### Escalabilidad

- Target Tracking Scaling: CPU target 60%, escala en ~2 min
- Rolling deployment: min 50% healthy, max 200% durante deploy
- Circuit breaker de ECS habilitado para rollback automático

## Demo

Ubicación: [`../../demos/ecs-scaling-demo/`](../../demos/ecs-scaling-demo/)

**Flujo:**

1. API REST expuesta via ALB
2. Dashboard CloudWatch con métricas en tiempo real
3. Script de carga para demostrar autoscaling

## Estado

- [ ] Diagrama arquitectural
- [ ] Dockerfile de la API demo
- [ ] IaC Terraform
- [ ] Demo funcional con dashboard
- [ ] ADR adicionales documentados
