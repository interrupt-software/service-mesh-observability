data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

variable "instance_names" {
  type    = list(string)
  default = ["server01", "server02", "server03"]
}

variable "client_names" {
  type    = list(string)
  default = ["client01", "client02", "client03"]
}

variable "consul_version" {
  default = "1.10.2"
}

variable "grafana_password" {}
variable "gcloud_api_key" {}
variable "loki_api_key" {}
variable "prom_user" {}
variable "loki_user" {}

variable "cunsul_url" {
  default = "https://releases.hashicorp.com/consul"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_instance" "app" {
  count                  = length(var.instance_names)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh.key_name
  subnet_id              = aws_subnet.interrupt_public_subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.interrupt_app.id]
  depends_on             = [aws_internet_gateway.interrupt_gw]

  tags = merge({ "Name" = var.instance_names[count.index], "consul_role" = "server" }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_instance" "app_clients" {
  count                  = length(var.client_names)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh.key_name
  subnet_id              = aws_subnet.interrupt_public_subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.interrupt_app.id]
  depends_on             = [aws_internet_gateway.interrupt_gw]

  tags = merge({ "Name" = var.client_names[count.index], "consul_role" = "client" }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "bastion" {
  count                  = 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh.key_name
  subnet_id              = aws_subnet.interrupt_public_subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  depends_on             = [aws_internet_gateway.interrupt_gw]

  tags = merge({ "Name" = "bastion" }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "configure-service-mesh" {
  depends_on = [
    aws_instance.bastion,
    aws_instance.app,
    aws_instance.app_clients
  ]

  provisioner "local-exec" {
    command     = "bash bootstrap.bash"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "file" {
    source      = "~/.ssh/benderama"
    destination = "/home/ubuntu/.ssh/benderama"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "file" {
    source      = "client-packages.sh"
    destination = "/home/ubuntu/client-packages.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "file" {
    source      = "server-packages.sh"
    destination = "/home/ubuntu/server-packages.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 ~/.ssh/benderama",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[0].private_ip} -o \"StrictHostKeyChecking no\" 'bash -s' < server-packages.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[1].private_ip} -o \"StrictHostKeyChecking no\" 'bash -s' < server-packages.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[2].private_ip} -o \"StrictHostKeyChecking no\" 'bash -s' < server-packages.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[0].private_ip} -o \"StrictHostKeyChecking no\" 'bash -s' < client-packages.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[1].private_ip} -o \"StrictHostKeyChecking no\" 'bash -s' < client-packages.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[2].private_ip} -o \"StrictHostKeyChecking no\" 'bash -s' < client-packages.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "file" {
    source      = "init-consul-server.sh"
    destination = "/home/ubuntu/init-consul-server.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "file" {
    source      = "init-consul-client.sh"
    destination = "/home/ubuntu/init-consul-client.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "file" {
    source      = "init-nomad-server.sh"
    destination = "/home/ubuntu/init-nomad-server.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "file" {
    source      = "init-nomad-client.sh"
    destination = "/home/ubuntu/init-nomad-client.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[0].private_ip} 'bash -s' < init-consul-server.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[1].private_ip} 'bash -s' < init-consul-server.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[2].private_ip} 'bash -s' < init-consul-server.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[0].private_ip} 'bash -s' < init-nomad-server.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[1].private_ip} 'bash -s' < init-nomad-server.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[2].private_ip} 'bash -s' < init-nomad-server.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[0].private_ip} 'bash -s' < init-consul-client.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[1].private_ip} 'bash -s' < init-consul-client.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[2].private_ip} 'bash -s' < init-consul-client.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[0].private_ip} 'bash -s' < init-nomad-client.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[1].private_ip} 'bash -s' < init-nomad-client.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[2].private_ip} 'bash -s' < init-nomad-client.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "file" {
    source      = "init-grafana.tpl"
    destination = "/home/ubuntu/init-grafana.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[0].private_ip} LOKI_USER=\"${var.loki_user}\" LOKI_API_KEY=\"${var.loki_api_key}\" PROM_USER=\"${var.prom_user}\" GCLOUD_API_KEY=\"${var.gcloud_api_key}\" GRAFANA_PASS=\"${var.grafana_password}\" HOST_IP=\"${aws_instance.app[0].private_ip}\" 'bash -s' < init-grafana.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[1].private_ip} LOKI_USER=\"${var.loki_user}\" LOKI_API_KEY=\"${var.loki_api_key}\" PROM_USER=\"${var.prom_user}\" GCLOUD_API_KEY=\"${var.gcloud_api_key}\" GRAFANA_PASS=\"${var.grafana_password}\" HOST_IP=\"${aws_instance.app[1].private_ip}\" 'bash -s' < init-grafana.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app[2].private_ip} LOKI_USER=\"${var.loki_user}\" LOKI_API_KEY=\"${var.loki_api_key}\" PROM_USER=\"${var.prom_user}\" GCLOUD_API_KEY=\"${var.gcloud_api_key}\" GRAFANA_PASS=\"${var.grafana_password}\" HOST_IP=\"${aws_instance.app[2].private_ip}\" 'bash -s' < init-grafana.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[0].private_ip} LOKI_USER=\"${var.loki_user}\" LOKI_API_KEY=\"${var.loki_api_key}\" PROM_USER=\"${var.prom_user}\" GCLOUD_API_KEY=\"${var.gcloud_api_key}\" GRAFANA_PASS=\"${var.grafana_password}\" HOST_IP=\"${aws_instance.app_clients[0].private_ip}\" 'bash -s' < init-grafana.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[1].private_ip} LOKI_USER=\"${var.loki_user}\" LOKI_API_KEY=\"${var.loki_api_key}\" PROM_USER=\"${var.prom_user}\" GCLOUD_API_KEY=\"${var.gcloud_api_key}\" GRAFANA_PASS=\"${var.grafana_password}\" HOST_IP=\"${aws_instance.app_clients[1].private_ip}\" 'bash -s' < init-grafana.sh",
      "ssh -i ~/.ssh/benderama ubuntu@${aws_instance.app_clients[2].private_ip} LOKI_USER=\"${var.loki_user}\" LOKI_API_KEY=\"${var.loki_api_key}\" PROM_USER=\"${var.prom_user}\" GCLOUD_API_KEY=\"${var.gcloud_api_key}\" GRAFANA_PASS=\"${var.grafana_password}\" HOST_IP=\"${aws_instance.app_clients[2].private_ip}\" 'bash -s' < init-grafana.sh",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/benderama")
      host        = aws_instance.bastion[0].public_ip
    }
  }
}