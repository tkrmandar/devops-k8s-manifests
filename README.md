# DevOps K8s Manifests

Kubernetes manifests for task-manager-api.
Managed via GitOps with ArgoCD.

## Structure
- dev/        → Development environment manifests
- prod/blue/  → Production Blue environment
- prod/green/ → Production Green environment
- rbac/       → Role based access control
- network-policies/ → Ingress/Egress network rules
- monitoring/ → Prometheus & Grafana configs
