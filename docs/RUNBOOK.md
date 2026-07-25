# Build runbook — Ghost on EKS

Every step that creates or destroys billable resources is marked **[APPROVAL GATE]**.
Run from Windows PowerShell with awscli, kubectl, helm and terraform installed.

Multi-line commands use PowerShell's backtick continuation character, not bash
backslashes. A trailing space after a continuation backtick silently breaks the
command, so keep the backtick last on the line.

## Prerequisites
- AWS CLI configured with the free-tier build account (`aws sts get-caller-identity` works).
- `terraform`, `kubectl`, `helm` on PATH.
- Region is ap-south-1.

## Step 1 — Init Terraform
```
cd terraform
terraform init
```

## Step 2 — Review the plan
```
terraform plan
```
Read it. Confirm it creates: 1 VPC, 2 public + 2 private subnets, 1 NAT gateway,
1 EKS cluster, 1 managed node group (2 nodes), 1 IRSA role, 5 addons.

## Step 3 — [APPROVAL GATE] Apply
```
terraform apply
```
Takes ~15 min (the EKS control plane is the slow part). Note the outputs.

## Step 4 — Point kubectl at the cluster
Copy the `configure_kubectl` output and run it, e.g.:
```
aws eks update-kubeconfig --region ap-south-1 --name ghost-eks-cluster
kubectl get nodes          # expect 2 Ready nodes
```

## Step 5 — [APPROVAL GATE] Install the AWS Load Balancer Controller
This provisions no cloud resource by itself but is required before the Ingress works.
```powershell
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Run these from terraform/ so the outputs resolve.
$ROLE_ARN = terraform output -raw lb_controller_role_arn
$VPC_ID   = terraform output -raw vpc_id

# The \. sequences in the annotation key are Helm's own dot-escaping, not shell
# escapes — leave them as backslashes.
helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
  -n kube-system `
  --set clusterName=ghost-eks-cluster `
  --set serviceAccount.create=true `
  --set serviceAccount.name=aws-load-balancer-controller `
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$ROLE_ARN" `
  --set region=ap-south-1 `
  --set vpcId=$VPC_ID

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
```

## Step 6 — Install metrics-server (needed for HPA)
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deploy/metrics-server
```

## Step 7 — [APPROVAL GATE] Deploy the app
```
cd ../k8s
kubectl apply -f 00-namespace.yaml
kubectl apply -f 10-mysql.yaml
kubectl -n ghost rollout status statefulset/mysql
kubectl apply -f 20-ghost.yaml
kubectl apply -f 30-ingress-hpa.yaml
```

Get the ALB DNS name (may take 2-3 min to appear):
```
kubectl -n ghost get ingress ghost -w
```
When ADDRESS shows an amazonaws.com hostname, patch Ghost's url and let it
roll:
```
kubectl -n ghost set env deploy/ghost url=http://<ALB_DNS>
```
Visit `http://<ALB_DNS>` — Ghost should load. `http://<ALB_DNS>/ghost` is the admin setup.

## Step 8 — Demo 1: Ingress + multi-service
Screenshot: the Ghost site live on the ALB URL, plus `kubectl -n ghost get svc,ingress,pods`.

## Step 9 — Demo 2: Rolling update
```
kubectl -n ghost set image deploy/ghost ghost=ghost:5.90-alpine
kubectl -n ghost rollout status deploy/ghost
```
Screenshot: `kubectl -n ghost get pods` mid-roll (old + new pods), site stays up.

## Step 10 — Demo 3: Self-healing
Grab one Ghost pod name, delete it, and watch the ReplicaSet replace it:
```
kubectl -n ghost get pods -l app=ghost           # copy one pod name
kubectl -n ghost delete pod <ghost-pod-name>
kubectl -n ghost get pods -w
```
Screenshot: the deleted pod Terminating while a fresh pod goes
Pending -> ContainerCreating -> Running, all within seconds — replica count
never drops below the desired 2.

## Step 11 — Demo 4: HPA scale-out
```powershell
kubectl -n ghost get hpa ghost -w      # watch in one terminal
# in another, generate load:
# The quoted sh command runs inside the busybox container, so its ; separators
# are container-side shell and stay as they are.
kubectl -n ghost run load --image=busybox --restart=Never -- `
  /bin/sh -c "while true; do wget -q -O- http://ghost; done"
```
Screenshot: HPA TARGETS climbing past 50%, REPLICAS rising 2 -> 4+.
Clean up the load pod: `kubectl -n ghost delete pod load`.

## Step 12 — [APPROVAL GATE] Destroy
Delete the Ingress FIRST so the ALB is removed before the cluster:
```
kubectl -n ghost delete ingress ghost
# wait ~1 min for the ALB to disappear
cd ../terraform
terraform destroy
```
Confirm destroy completes with 0 resources remaining. Then check the console:
no leftover ALB, no leftover EBS volumes, no NAT gateway still running.
