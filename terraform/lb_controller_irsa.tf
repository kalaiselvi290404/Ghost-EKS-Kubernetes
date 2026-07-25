# IRSA (IAM Roles for Service Accounts) role that the AWS Load Balancer
# Controller pod assumes. This is the pod-level equivalent of an EC2 instance
# role: instead of long-lived keys, the controller's ServiceAccount is
# federated through the cluster's OIDC provider to assume this role.
#
# The module's attach_load_balancer_controller_policy flag pulls in the
# current, correct IAM policy maintained upstream — no hand-written JSON.
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                              = "${var.project_name}-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}
