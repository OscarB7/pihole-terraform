data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = var.oci_tenancy_ocid
}


resource "oci_core_vcn" "pihole_vcn" {
  compartment_id = var.oci_tenancy_ocid
  cidr_blocks    = var.vcn_cidr_blocks
  display_name   = var.vcn_display_name
}


resource "oci_core_internet_gateway" "pihole_internet_gateway" {
  compartment_id = var.oci_tenancy_ocid
  vcn_id         = oci_core_vcn.pihole_vcn.id
  enabled        = true
  display_name   = var.internet_gateway_display_name
}


resource "oci_core_route_table" "pihole_route_table" {
  compartment_id = var.oci_tenancy_ocid
  vcn_id         = oci_core_vcn.pihole_vcn.id
  display_name   = var.route_table_display_name
  route_rules {
    network_entity_id = oci_core_internet_gateway.pihole_internet_gateway.id
    description       = "Internet access"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}


resource "oci_core_security_list" "pihole_security_list" {
  compartment_id = var.oci_tenancy_ocid
  vcn_id         = oci_core_vcn.pihole_vcn.id
  display_name   = var.security_list_display_name
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    description = "allow all outbound traffic from the instance"
    stateless   = false
  }
  ingress_security_rules {
    protocol    = 6 # 6=TCP
    source      = var.your_home_public_ip
    description = "allow 22/TCP (SSH) inbound traffic from home"
    stateless   = false
    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    protocol    = 17 # 17=UDP
    source      = "0.0.0.0/0"
    description = "allow <WireGuard Port>/UDP (WireGuard) inbound traffic from anywhere"
    stateless   = false
    udp_options {
      max = var.port_wireguard
      min = var.port_wireguard
    }
  }
  ingress_security_rules {
    protocol    = 6 # 6=TCP
    source      = var.your_home_public_ip
    description = "allow <Pihole DNS Port>/TCP (Pihole DNS) inbound traffic from home"
    stateless   = false
    tcp_options {
      max = var.port_pihole_dns
      min = var.port_pihole_dns
    }
  }
  ingress_security_rules {
    protocol    = 17 # 17=UDP
    source      = var.your_home_public_ip
    description = "allow <Pihole DNS Port>/UDP (Pihole DNS) inbound traffic from home"
    stateless   = false
    udp_options {
      max = var.port_pihole_dns
      min = var.port_pihole_dns
    }
  }
  ingress_security_rules {
    protocol    = 6 # 6=TCP
    source      = var.your_home_public_ip
    description = "allow <Pihole web Port>/TCP (Pihole web) inbound traffic from home"
    stateless   = false
    tcp_options {
      max = var.port_pihole_web
      min = var.port_pihole_web
    }
  }
}


resource "oci_core_subnet" "public_subnet" {
  cidr_block          = var.subnet_cidr_block
  compartment_id      = var.oci_tenancy_ocid
  vcn_id              = oci_core_vcn.pihole_vcn.id
  availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0]["name"]
  display_name        = var.subnet_display_name
  route_table_id      = oci_core_route_table.pihole_route_table.id
  security_list_ids   = [oci_core_security_list.pihole_security_list.id]
}


# TODO: create a key to encrypt boot volume. kmsKeyId
# TODO: create elastic IP for OCI and use it for this instance


data "oci_core_images" "ubuntu_image" {
  compartment_id           = var.oci_tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "20.04"
  shape                    = var.instance_shape
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}


resource "oci_core_instance" "pihole_wireguard" {
  availability_domain = data.oci_identity_availability_domains.availability_domains.availability_domains[0]["name"]
  compartment_id      = var.oci_tenancy_ocid
  shape               = var.instance_shape
  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
  }
  display_name = var.instance_display_name
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile(
      "user_data/bootstrap.tftpl",
      {
        docker_compose_version       = var.docker_compose_version,
        docker_network_range         = var.docker_network_range,
        docker_compose_network_range = var.docker_compose_network_range,
        pihole_ip                    = var.pihole_ip,
        pihole_dns_port              = var.pihole_dns_port,
        pihole_web_port              = var.pihole_web_port,
        wg_port                      = var.wg_port,
        wg_server_private_key        = var.wg_server_private_key,
        wg_server_ip                 = var.wg_server_ip,
        wg_server_port               = var.wg_server_port,
        wg_client_public_key         = var.wg_client_public_key,
        wg_client_ip                 = var.wg_client_ip,
        tz                           = var.tz,
        pihole_webpassword           = var.pihole_webpassword,
        pihole_dns_ip                = var.pihole_dns_ip
      }
    ))
  }
  shape_config {
    baseline_ocpu_utilization = var.instance_shape_config_baseline_ocpu_utilization
    memory_in_gbs             = var.instance_shape_config_memory_in_gbs
    ocpus                     = var.instance_shape_config_ocpus
  }
  source_details {
    source_id               = data.oci_core_images.ubuntu_image.images.0.id
    source_type             = "image"
    boot_volume_size_in_gbs = var.instance_source_details_boot_volume_size_in_gbs
  }
  preserve_boot_volume = false
}
