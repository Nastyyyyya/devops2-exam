terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
  }
  backend "s3" {
    endpoint                    = "https://fra1.digitaloceanspaces.com"
    region                      = "us-east-1"
    bucket                      = "paslavska-bucket"
    key                         = "terraform.tfstate"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
  }
}

variable "do_token" {}

provider "digitalocean" {
  token = var.do_token
}

# --- 1. SSH KEY GENERATION ---
resource "tls_private_key" "paslavska_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "digitalocean_ssh_key" "paslavska_key" {
  name       = "paslavska-control-node-key"
  public_key = tls_private_key.paslavska_ssh_key.public_key_openssh
}

# Збереження приватного ключа для Ansible
resource "local_file" "paslavska_private_key" {
  content         = tls_private_key.paslavska_ssh_key.private_key_pem
  filename        = "${path.module}/id_rsa.pem"
  file_permission = "0600"
}

# --- 2. VPC ---
data "digitalocean_vpc" "existing_vpc" {
  name = "paslavska-vpc"
}

# --- 3. DROPLET ---
resource "digitalocean_droplet" "paslavska_node" {
  name     = "paslavska-node"
  region   = "fra1"
  size     = "s-4vcpu-8gb"
  image    = "ubuntu-24-04-x64"
  vpc_uuid = data.digitalocean_vpc.existing_vpc.id
  ssh_keys = [digitalocean_ssh_key.paslavska_key.id]

  # Динамічне створення inventory.ini
  provisioner "local-exec" {
    command = "echo '[paslavska_nodes]\n${self.ipv4_address} ansible_user=root ansible_ssh_private_key_file=task1/id_rsa.pem ansible_ssh_common_args=\"-o StrictHostKeyChecking=no\"' > ../task2/inventory.ini"
  }
}

# --- 4. FIREWALL ---
resource "digitalocean_firewall" "paslavska_firewall" {
  name        = "paslavska-firewall"
  droplet_ids = [digitalocean_droplet.paslavska_node.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8000-8003"
    source_addresses = ["0.0.0.0/0"]
  }
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "droplet_ip" {
  value = digitalocean_droplet.paslavska_node.ipv4_address
}
