provider "aws" {
  region = "us-east-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "ami_id" {
  default = "ami-0a91cd140a1fc148a"
}

variable "subnet_id" {
  description = "ID da Subnet para as instâncias"
}

variable "security_group_id" {
  description = "ID do Security Group para as instâncias"
}

resource "aws_instance" "vm_gslb" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.subnet_id
  security_groups = [var.security_group_id]
  tags = {
    Name = "vm-gslb"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y haproxy"
    ]
  }
}

resource "aws_instance" "vm_ceph" {
  count           = 3
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.subnet_id
  security_groups = [var.security_group_id]
  tags = {
    Name = "vm-ceph-${count.index + 1}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y ceph-deploy",
      "mkdir -p ceph-cluster && cd ceph-cluster",
      "ceph-deploy new ${self.private_ip}",
      "ceph-deploy install ${self.private_ip}",
      "ceph-deploy mon create-initial",
      "ceph-deploy osd create ${self.private_ip}:/dev/sdb"
    ]
  }
}

resource "aws_instance" "vm_lb" {
  count           = 2
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.subnet_id
  security_groups = [var.security_group_id]
  tags = {
    Name = "vm-lb-${count.index + 1}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y haproxy",
      "mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg",
      "sudo systemctl restart haproxy"
    ]

    connection {
      host        = ""
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("<path_to_your_private_key>")
    }
  }
}

resource "aws_instance" "vm_cluster" {
  count           = 6
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = var.subnet_id
  security_groups = [var.security_group_id]
  tags = {
    Name = "vm-cluster-${count.index + 1}"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | K3S_TOKEN=SECRET sh -s -",
      "echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf",
      "sysctl -p"
    ]
  }
}

resource "aws_security_group" "sg_example" {
  name_prefix = "example-sg-"
  description = "Allow traffic for VMs"

  ingress {
    description      = "Allow all inbound traffic for VMs"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

output "vm_ips" {
  value = {
    "gslb"   = aws_instance.vm_gslb.private_ip
    "ceph"   = [for instance in aws_instance.vm_ceph : instance.private_ip]
    "lb"     = [for instance in aws_instance.vm_lb : instance.private_ip]
    "cluster" = [for instance in aws_instance.vm_cluster : instance.private_ip]
  }
}
