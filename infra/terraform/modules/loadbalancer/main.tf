resource "aws_lb" "k8s_api" {
  name               = "securerag-${var.environment}-api-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "securerag-${var.environment}-api-nlb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "k8s_api" {
  name        = "securerag-${var.environment}-tg-6443"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    port                = 6443
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = {
    Name        = "securerag-${var.environment}-tg-6443"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "k8s_api_alt" {
  name        = "securerag-${var.environment}-tg-8443"
  port        = 8443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    port                = 8443
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = {
    Name        = "securerag-${var.environment}-tg-8443"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "k8s_api" {
  load_balancer_arn = aws_lb.k8s_api.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_api.arn
  }
}

resource "aws_lb_listener" "k8s_api_alt" {
  load_balancer_arn = aws_lb.k8s_api.arn
  port              = 8443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_api_alt.arn
  }
}

resource "aws_lb_target_group_attachment" "k8s_api" {
  count            = length(var.control_plane_ids)
  target_group_arn = aws_lb_target_group.k8s_api.arn
  target_id        = var.control_plane_ids[count.index]
  port             = 6443
}

resource "aws_lb_target_group_attachment" "k8s_api_alt" {
  count            = length(var.control_plane_ids)
  target_group_arn = aws_lb_target_group.k8s_api_alt.arn
  target_id        = var.control_plane_ids[count.index]
  port             = 8443
}
