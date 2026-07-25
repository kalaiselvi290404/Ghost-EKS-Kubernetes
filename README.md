# ghost-eks-kubernetes

Deploying the open-source Ghost publishing platform to **Amazon EKS**, with a
MySQL data tier, an ALB provisioned through the AWS Load Balancer Controller,
and Horizontal Pod Autoscaling. Region: ap-south-1.

Infrastructure is provisioned with **Terraform**; the workloads are defined as
hand-written **Kubernetes manifests** applied with `kubectl`.

## Architecture
```
Internet
   |
  ALB  (internet-facing, provisioned by AWS Load Balancer Controller)
   |  Ingress
   v
Ghost Deployment (2+ replicas, stateless web tier)  <-- HPA scales on CPU
   |
MySQL StatefulSet (EBS-backed PVC, durable data tier)
```
All running on an EKS managed node group across two availability zones.

## What it demonstrates
- **Ingress + multi-service** — ALB routes to the Ghost Service; Ghost talks to the MySQL Service.
- **Rolling updates** — `maxUnavailable: 0` for zero-downtime image rollouts.
- **Self-healing** — deleting a pod triggers automatic recreation by the ReplicaSet.
- **HPA** — pod-level autoscaling on CPU, the Kubernetes analogue of an EC2 Auto Scaling Group.

## Layout
- `terraform/` — VPC, EKS cluster, managed node group, EBS CSI addon, IRSA role for the LB controller.
- `k8s/` — namespace, MySQL (Secret + headless Service + StatefulSet), Ghost (Deployment + Service), Ingress + HPA.
- `docs/RUNBOOK.md` — exact build, demo, and teardown commands.
- `CLAUDE.md` — approval gates and cost discipline for the build.

## Build and teardown
See `docs/RUNBOOK.md`. This is a build-and-destroy project: the EKS control
plane is not free-tier, so the cluster is stood up, evidence captured, and torn
down via `terraform destroy` the same day.

## Key design decisions
- **In-cluster MySQL (StatefulSet)** rather than RDS — keeps the project self-contained and demonstrates stateful workloads and the EBS CSI driver.
- **Hand-written manifests** rather than a Helm chart for the app — every object is explainable line by line.
- **IRSA** for the LB controller — the pod assumes an IAM role via the cluster OIDC provider, with no long-lived keys.
