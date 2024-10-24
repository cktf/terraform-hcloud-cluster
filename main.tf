terraform {
  required_version = ">= 1.5.0"
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.0.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.31.0"
    }
  }
}
