output "cluster_name" {
  description = "EKS cluster name — used in the kubeconfig update command"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region — used in the kubeconfig update command"
  value       = var.region
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "lb_controller_role_arn" {
  description = "IAM role ARN to annotate onto the aws-load-balancer-controller ServiceAccount"
  value       = module.lb_controller_irsa.iam_role_arn
}

output "vpc_id" {
  description = "VPC ID — needed as a Helm value when installing the LB controller"
  value       = module.vpc.vpc_id
}
