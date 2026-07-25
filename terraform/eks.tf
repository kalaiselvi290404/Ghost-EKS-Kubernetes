module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.project_name}-cluster"
  kubernetes_version = var.cluster_version

  # Public endpoint so kubectl works from the local workstation.
  endpoint_public_access = true

  # Adds the identity running terraform (Kalaiselvi's admin creds) as a
  # cluster administrator via an EKS access entry — this is how v21 replaces
  # the old aws-auth ConfigMap. Without this, kubectl would be locked out.
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Core addons. The EBS CSI driver is what lets the MySQL StatefulSet's
  # PersistentVolumeClaim actually provision an EBS volume.
  addons = {
    coredns    = {}
    kube-proxy = {}
    # The CSI driver needs an AWS identity to call EC2 (CreateVolume,
    # AttachVolume). Without this the controller crash-loops.
    aws-ebs-csi-driver = { service_account_role_arn = module.ebs_csi_irsa.iam_role_arn }
    # before_compute installs these before the node group joins, so pod
    # networking and identity are ready when nodes come up (avoids a race).
    eks-pod-identity-agent = { before_compute = true }
    vpc-cni                = { before_compute = true }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }

  tags = local.tags
}
