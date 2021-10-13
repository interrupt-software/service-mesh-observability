# Create a new instance of the latest Ubuntu on an EC2 instance,
# t2.micro node. If you are not sure of what you are trying to find,
# try this using the AWS command line:
#
#  aws ec2 describe-images --owners 099720109477 \
#    --filters "Name=name,Values=*hvm-ssd*bionic*18.04-amd64*" \
#    --query 'sort_by(Images, &CreationDate)[].Name'
#
# aws ec2 describe-images --owners 099720109477 \
#   --filters "Name=name,Values=*hvm-ssd*focal*20.04-amd64*" \
#   --query 'sort_by(Images, &CreationDate)[].Name'

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

variable "private_subnet" {
  type    = list(string)
  default = ["10.168.1.0/24", "10.168.2.0/24", "10.168.3.0/24"]

}

variable "public_subnet" {
  type    = list(string)
  default = ["10.168.101.0/24", "10.168.102.0/24", "10.168.103.0/24"]
}

resource "aws_vpc" "interrupt_vpc" {
  cidr_block           = "10.168.0.0/16"
  enable_dns_hostnames = true

  tags = merge({ "Name" = "Interrupt VPC" }, var.tags)
}

resource "aws_subnet" "interrupt_private_subnet" {
  count                   = length(var.private_subnet)
  vpc_id                  = aws_vpc.interrupt_vpc.id
  cidr_block              = var.private_subnet[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = merge({ "Name" = "Interrupt Private Subnet" }, var.tags)
}

resource "aws_subnet" "interrupt_public_subnet" {
  count                   = length(var.public_subnet)
  vpc_id                  = aws_vpc.interrupt_vpc.id
  cidr_block              = var.public_subnet[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge({ "Name" = "Interrupt Public Subnet" }, var.tags)
}

resource "aws_security_group" "interrupt_app" {
  name        = "interrupt_app"
  description = "Interrupt inbound traffic"
  vpc_id      = aws_vpc.interrupt_vpc.id
  tags        = merge({ "Name" = "Interrupt App NSG" }, var.tags)
}

resource "aws_security_group" "bastion" {
  name        = "bastion_sg"
  description = "Bastion Host Security Group"
  vpc_id      = aws_vpc.interrupt_vpc.id
  tags        = merge({ "Name" = "Bastion NSG" }, var.tags)
}

resource "aws_security_group_rule" "allow_public_bastion_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_allow_all" {
  description       = "Allow all outbound traffic."
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "allow_bastion_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "consul_api_lb" {
  description              = "LB HTTP API"
  type                     = "ingress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.app_lb.id
}

resource "aws_security_group_rule" "consul_rpc" {
  description              = "Server RPC"
  type                     = "ingress"
  from_port                = 8300
  to_port                  = 8300
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.interrupt_app.id
}


resource "aws_security_group_rule" "consul_lan_serf" {
  description              = "Serf LAN"
  type                     = "ingress"
  from_port                = 8301
  to_port                  = 8301
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.interrupt_app.id
}

resource "aws_security_group_rule" "consul_api" {
  description              = "HTTP API"
  type                     = "ingress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.interrupt_app.id
}

resource "aws_security_group_rule" "consul_dns" {
  description              = "DNS Interface"
  type                     = "ingress"
  from_port                = 8600
  to_port                  = 8600
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.interrupt_app.id
}

resource "aws_security_group_rule" "nomad_api" {
  description              = "Nomad API"
  type                     = "ingress"
  from_port                = 4646
  to_port                  = 4646
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.interrupt_app.id
}

resource "aws_security_group_rule" "nomad_rpc" {
  description              = "Nomad RPC"
  type                     = "ingress"
  from_port                = 4647
  to_port                  = 4647
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.interrupt_app.id
}

resource "aws_security_group_rule" "nomad_serf" {
  description              = "Nomad SERF"
  type                     = "ingress"
  from_port                = 4648
  to_port                  = 4648
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interrupt_app.id
  source_security_group_id = aws_security_group.interrupt_app.id
}

resource "aws_security_group_rule" "app_allow_all" {
  description       = "Allow all outbound traffic."
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.interrupt_app.id
}

resource "aws_internet_gateway" "interrupt_gw" {
  vpc_id = aws_vpc.interrupt_vpc.id
  tags   = merge({ "Name" = "Interrupt Gateway" }, var.tags)
}

resource "aws_route_table" "interrupt_rt" {
  vpc_id = aws_vpc.interrupt_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.interrupt_gw.id
  }
  tags = merge({ "Name" = "Interrupt Routing Table" }, var.tags)
}

// resource "aws_route_table_association" "interrupt_bastion" {
//   subnet_id      = aws_subnet.interrupt_public_subnet[0].id
//   route_table_id = aws_route_table.interrupt_rt.id
// }

# resource "null_resource" "plant_keys" {
#   provisioner "local-exec" {
#     command = "scp -i /Users/bender/.ssh/benderama -o \"StrictHostKeyChecking no\" /Users/bender/.ssh/benderama ubuntu@${data.aws_instance.bastion.public_ip}:/home/ubuntu/."
#     # command = "ifconfig -a ; ssh -i ~/.ssh/benderama -o \"StrictHostKeyChecking no\" ubuntu@${data.aws_instance.bastion.public_ip}"
#     interpreter = ["/bin/bash", "-c"]
#   }
# }

resource "aws_route_table_association" "interrupt_app" {
  count          = length(var.public_subnet)
  subnet_id      = aws_subnet.interrupt_public_subnet[count.index].id
  route_table_id = aws_route_table.interrupt_rt.id
}

resource "aws_key_pair" "ssh" {
  key_name   = var.key_name
  public_key = file("~/.ssh/benderama.pub")
}

output "server_seeds" {
  value = aws_instance.app.*.private_ip
}

output "client_seeds" {
  value = aws_instance.app_clients.*.private_ip
}

data "aws_instance" "awsvm" {
  instance_id = aws_instance.app[0].id
}

output "private_ip" {
  value       = data.aws_instance.awsvm.private_ip
  description = "The private IP of the web server"
}

# Create customized output for reference. In this case, a local variable and a data source.
data "aws_instance" "bastion" {
  instance_id = aws_instance.bastion[0].id
}

output "public_ip_bastion" {
  value       = data.aws_instance.bastion.public_ip
  description = "The public IP of the web server"
}

output "ssh_command_bastion" {
  value = "ssh -i ~/.ssh/benderama ubuntu@${data.aws_instance.bastion.public_ip}"
}

output "scp_command_bastion" {
  value = "scp -i /Users/bender/.ssh/benderama -o \"StrictHostKeyChecking no\" ~/.ssh/benderama ubuntu@${data.aws_instance.bastion.public_ip}:/home/ubuntu/."
}

output "ssh_command_web" {
  value = "ssh -i ~/benderama ubuntu@${data.aws_instance.awsvm.private_ip}"
}

resource "tls_private_key" "interrupt" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "interrupt" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.interrupt.private_key_pem

  subject {
    common_name  = "interrupt-software.xyz"
    organization = "Interrupt Software"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.interrupt.private_key_pem
  certificate_body = tls_self_signed_cert.interrupt.cert_pem

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app_lb" {
  name        = "app_lb_sg"
  description = "App Server Load Balancer Security Group"
  vpc_id      = aws_vpc.interrupt_vpc.id
}

resource "aws_lb" "app" {
  name               = "app-test"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.interrupt_public_subnet.*.id
  security_groups    = [aws_security_group.app_lb.id]

  tags = {
    Name        = "app-test"
    Environment = "test"
  }
}

resource "aws_security_group_rule" "allow_inbound_consul" {
  type              = "ingress"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app_lb.id
}

resource "aws_security_group_rule" "allow_consul_http" {
  type                     = "egress"
  from_port                = 8500
  to_port                  = 8500
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_lb.id
  source_security_group_id = aws_security_group.interrupt_app.id
}

# redirect insecure traffic to HTTPS
resource "aws_lb_listener" "consul_http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 8500
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul_http.arn
  }
}

resource "aws_lb_target_group" "consul_http" {
  name     = "app-test-http"
  port     = 8500
  protocol = "HTTP"
  vpc_id   = aws_vpc.interrupt_vpc.id
}

resource "aws_lb_target_group_attachment" "consul_http" {
  count            = length(aws_instance.app)
  target_group_arn = aws_lb_target_group.consul_http.arn
  target_id        = aws_instance.app[count.index].id
  port             = 8500
}

output "lb_dns_name" {
  value       = "http://${aws_lb.app.dns_name}"
  description = "The DNS name of the application load balancer"
}

output "consul_entry_point" {
  value       = "http://${aws_lb.app.dns_name}:8500"
  description = "The DNS name of the application load balancer"
}