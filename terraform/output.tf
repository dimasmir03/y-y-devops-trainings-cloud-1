#output "external_ip_1" {
#  value = "${yandex_compute_instance.*.network_interface.0.nat_ip_address}"
#}