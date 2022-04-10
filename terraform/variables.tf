# ----- provider -----

variable "oci_region" {
  type      = string
  sensitive = true
}

variable "oci_tenancy_ocid" {
  type      = string
  sensitive = true
}

variable "oci_user_ocid" {
  type      = string
  sensitive = true
}

variable "oci_fingerprint" {
  type      = string
  sensitive = true
}

variable "oci_private_key_base64" {
  type      = string
  sensitive = true
}


# ----- resources -----

# Base/Shared

variable "oci_vcn_id" {
  type      = string
  sensitive = false
  default   = null
}

variable "oci_internet_gateway_id" {
  type      = string
  sensitive = false
  default   = null
}

variable "oci_route_table_id" {
  type      = string
  sensitive = false
  default   = null
}

variable "oci_security_list_id" {
  type      = string
  sensitive = false
  default   = null
}

variable "oci_subnet_id" {
  type      = string
  sensitive = false
  default   = null
}

variable "oci_image_id" {
  type      = string
  sensitive = false
  default   = null
}


# VCN

variable "vcn_cidr_blocks" {
  type      = list(any)
  sensitive = false
  default   = ["172.16.0.0/20"]
}

variable "vcn_display_name" {
  type      = string
  sensitive = false
  default   = "pihole-wireguard-vns"
}

# Network

variable "internet_gateway_display_name" {
  type      = string
  sensitive = false
  default   = "pihole-wireguard-igw"
}

variable "route_table_display_name" {
  type      = string
  sensitive = false
  default   = "pihole-wireguard-rt"
}

variable "security_list_display_name" {
  type      = string
  sensitive = false
  default   = "pihole-wireguard-sl"
}

variable "port_wireguard" {
  type      = number
  sensitive = false
  default   = 51820
}

variable "port_pihole_dns" {
  type      = number
  sensitive = false
  default   = 53
}

variable "port_pihole_web" {
  type      = number
  sensitive = false
  default   = 80
}

variable "subnet_cidr_block" {
  type      = string
  sensitive = false
  default   = "172.16.0.0/24"
}

variable "subnet_display_name" {
  type      = string
  sensitive = false
  default   = "pihole-wireguard-vns"
}

variable "your_home_public_ip" {
  type      = string
  sensitive = true
}

variable "reserved_public_ip" {
  type      = string
  sensitive = false
  default   = "pihole-wireguard-public-ip"
}

# Instance

variable "instance_shape" {
  type      = string
  sensitive = false
  default   = "VM.Standard.A1.Flex"
}

variable "instance_display_name" {
  type      = string
  sensitive = false
  default   = "pihole-wireguard"
}

variable "instance_shape_config_baseline_ocpu_utilization" {
  type      = string
  sensitive = false
  default   = "BASELINE_1_1"
}

variable "instance_shape_config_memory_in_gbs" {
  type      = number
  sensitive = false
  default   = 6
}

variable "instance_shape_config_ocpus" {
  type      = number
  sensitive = false
  default   = 1
}

variable "instance_source_details_boot_volume_size_in_gbs" {
  type      = number
  sensitive = false
  default   = 50
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

# user data


variable "docker_compose_version" {
  type      = string
  sensitive = false
  default   = "2.1.1"
}

variable "docker_network_range" {
  type      = string
  sensitive = false
  default   = "10.7.0.0/16"
}

variable "docker_compose_network_range" {
  type      = string
  sensitive = false
  default   = "10.7.107.0/24"
}

variable "pihole_ip" {
  type      = string
  sensitive = false
  default   = "10.7.107.101"
}

variable "pihole_dns_port" {
  type      = string
  sensitive = false
  default   = "53"
}

variable "pihole_web_port" {
  type      = string
  sensitive = false
  default   = "80"
}

variable "wg_port" {
  type      = string
  sensitive = false
  default   = "51820"
}

variable "wg_server_private_key" {
  type      = string
  sensitive = true
}

variable "wg_server_ip" {
  type      = string
  sensitive = false
  default   = "10.6.0.1/24"
}

variable "wg_server_port" {
  type      = string
  sensitive = false
  default   = "51820"
}

variable "wg_client_public_key" {
  type      = string
  sensitive = true
}

variable "wg_client_ip" {
  type      = string
  sensitive = false
  default   = "10.6.0.2/32"
}

variable "tz" {
  type      = string
  sensitive = false
  default   = "America/New_York"
}

variable "pihole_webpassword" {
  type      = string
  sensitive = true
}

variable "pihole_dns_ip" {
  type      = string
  sensitive = false
  default   = "1.1.1.1"
}
