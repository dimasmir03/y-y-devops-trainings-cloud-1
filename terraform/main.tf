terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}
provider "yandex" {
  service_account_key_file = "./key.json"
  #token     = var.oauth_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-a"
}
resource "yandex_vpc_network" "network-1" {}
resource "yandex_vpc_subnet" "subnet-1" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}
resource "yandex_vpc_subnet" "subnet-2" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["10.6.0.0/24"]
}
data "yandex_compute_image" "coi" {
  family = "container-optimized-image"
}
resource "yandex_compute_instance_group" "ig-coi" {
  name = "ig-coi"
  folder_id = var.folder_id
  service_account_id = var.service_account_id
  instance_template {
    platform_id = "standard-v2"
    resources {
      memory = 1
      cores  = 2
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = data.yandex_compute_image.coi.id
      }
    }
    network_interface {
      network_id = yandex_vpc_network.network-1.id
      subnet_ids = ["${yandex_vpc_subnet.subnet-1.id}","${yandex_vpc_subnet.subnet-2.id}"]
      nat = false
    }
    metadata = {
      docker-compose = file("./docker-compose.yaml")
      ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
  }
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 2
    max_creating = 2
    max_expansion = 2
    max_deleting = 2
  }

  load_balancer {
    target_group_name = "auto-group-tg"
  }
}
resource "yandex_lb_network_load_balancer" "load-balancer" {
  name = "load-balancer"

  listener {
    name = "listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = "${yandex_compute_instance_group.ig-coi.load_balancer[0].target_group_id}"

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}