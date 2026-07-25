# CLAUDE.md — Project 4: Ghost on EKS

## What this project is
A containerized open-source app (Ghost blog) deployed to Amazon EKS with a
MySQL data tier, fronted by an ALB via the AWS Load Balancer Controller, with
Horizontal Pod Autoscaling. Region: ap-south-1 (Mumbai). Portfolio project for
Kalaiselvi P V (GitHub: kalaiselvi290404).

## Non-negotiable approval gates
Claude Code MUST pause and get explicit human approval BEFORE:
- Running `terraform apply` (creates billable EKS control plane + nodes + NAT).
- Running any `kubectl apply` that provisions cloud resources (the Ingress
  provisions a real ALB; the MySQL PVC provisions a real EBS volume).
- Running `terraform destroy`.

Never disable approval gates. Never auto-approve. Kalaiselvi approves each
infrastructure step manually, exactly as in Projects 2 and 3.

## Cost discipline
- EKS control plane bills ~$0.10/hr and is NOT free-tier.
- This is a build-and-destroy project: stand up, capture evidence, tear down
  the same day.
- The final step is ALWAYS `terraform destroy`, confirmed to hit 0 resources.
- After destroy, verify in the console that the ALB and EBS volumes are gone
  (orphaned ALBs/EBS keep billing after the cluster is deleted).

## Order of operations
1. `terraform apply` in terraform/ — cluster, nodes, VPC, IRSA role.
2. Update kubeconfig (see terraform output `configure_kubectl`).
3. Install the AWS Load Balancer Controller via Helm (runbook step 5).
4. `kubectl apply` manifests in k8s/ in filename order (00 → 30).
5. Backfill the real ALB DNS into the Ghost `url` env and the demos.
6. Run the four demos, capture screenshots.
7. `terraform destroy`.

## Verified talking points to preserve across docs
- Web tier (Ghost) is a stateless Deployment; data tier (MySQL) is a
  StatefulSet with an EBS-backed PVC — disposable vs durable.
- The LB Controller assumes an IRSA role via the cluster OIDC provider — pod
  gets AWS permissions without long-lived keys (same principle as the EC2
  instance role in earlier projects).
- HPA scales pods on CPU; this is the pod-level analogue of Project 3's
  CloudWatch alarm driving the EC2 ASG. Autoscaling demonstrated at two layers.
- RollingUpdate with maxUnavailable=0 gives zero-downtime deploys — the
  Kubernetes-native echo of the Ansible rolling deploy in Project 2.

## Accuracy rules (carried from prior projects)
- Only real, verified, reproducible steps go in the documentation.
- No fabricated metrics. Screenshot evidence backs every claim.
- If something wasn't actually run and verified, it does not go in the PDF.
