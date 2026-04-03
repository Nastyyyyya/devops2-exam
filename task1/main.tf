terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
  # Зберігання стану у хмарі 
  backend "s3" {
    endpoint                    = "fra1.digitaloceanspaces.com"
    region                      = "us-east-1" 
    bucket                      = "paslavska-bucket" 
    key                         = "terraform.tfstate"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}

variable "do_token" {}

provider "digitalocean" {
  token = var.do_token
}

# 1. VPC (Віртуальна приватна хмара)
resource "digitalocean_vpc" "vpc" {
  name     = "paslavska-vpc" 
  region   = "fra1" 
  ip_range = "10.10.10.0/24"
}

# 2. Droplet (Віртуальна машина)
resource "digitalocean_droplet" "node" {
  name     = "paslavska-node" 
  region   = "fra1" 
  size     = "s-2vcpu-4gb" # Системні вимоги для Minikube 
  image    = "ubuntu-24-04-x64" 
  vpc_uuid = digitalocean_vpc.vpc.id
}

# 3. Firewall (Фаєрвол)
resource "digitalocean_firewall" "firewall" {
  name        = "paslavska-firewall" 
  droplet_ids = [digitalocean_droplet.node.id]

  # Вхідні правила
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8000-8003" 
    source_addresses = ["0.0.0.0/0"]
  }

  # Вихідні правила
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535" 
    destination_addresses = ["0.0.0.0/0"]
  }
}