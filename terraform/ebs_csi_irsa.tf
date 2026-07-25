# IRSA role for the EBS CSI driver controller, following the same pattern as
# lb_controller_irsa.tf: the ServiceAccount is federated through the cluster's
# OIDC provider to assume this role, so no long-lived keys are involved.
#
# Without this the controller has no AWS identity at all — it falls back to
# node IMDS, fails its EC2 dry-run health check, and crash-loops, which leaves
# the addon stuck in CREATING and every PersistentVolumeClaim Pending.
#
# attach_ebs_csi_policy pulls in the upstream-maintained AmazonEBSCSIDriverPolicy.
# The service account name is fixed by the addon itself: ebs-csi-controller-sa.
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name             = "${var.project_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}
