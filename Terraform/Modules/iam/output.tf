output "lb_sa_name" {
  value = kubernetes_service_account.alb_sa.metadata[0].name
}

output "iam_role_alb_controller_arn" {
  value = aws_iam_role.alb_controller.arn
}