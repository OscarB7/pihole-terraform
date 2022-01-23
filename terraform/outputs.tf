output "availability_domains" {
  value = data.oci_identity_availability_domains.availability_domains.availability_domains[0]["name"]
}

output "image_name" {
  value = data.oci_core_images.ubuntu_image.images.0.display_name
}

output "image_id" {
  value = data.oci_core_images.ubuntu_image.images.0.id
}

output "port_pihole_dns" {
  value = var.port_pihole_dns
}

output "port_pihole_web" {
  value = var.port_pihole_web
}

output "instance_public_ip" {
  value = oci_core_instance.pihole_wireguard.public_ip
}
