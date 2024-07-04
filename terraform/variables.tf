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
  default   = null
}

variable "oci_internet_gateway_id" {
  type      = string
  default   = null
}

variable "oci_route_table_id" {
  type      = string
  default   = null
}

variable "oci_security_list_id" {
  type      = string
  default   = null
}

variable "oci_subnet_id" {
  type      = string
  default   = null
}

variable "oci_image_id" {
  type      = string
  default   = null
}


# VCN

variable "vcn_cidr_blocks" {
  type      = list(any)
  default   = ["172.16.0.0/20"]
}

variable "vcn_display_name" {
  type      = string
  default   = "pihole-wireguard-vcn"
}

# Network

variable "internet_gateway_display_name" {
  type      = string
  default   = "pihole-wireguard-igw"
}

variable "route_table_display_name" {
  type      = string
  default   = "pihole-wireguard-rt"
}

variable "security_list_display_name" {
  type      = string
  default   = "pihole-wireguard-sl"
}

variable "port_wireguard" {
  type      = number
  default   = 51820
}

variable "port_pihole_dns" {
  type      = number
  default   = 53
}

variable "port_pihole_web" {
  type      = number
  default   = 8080
}

variable "port_proxy_http" {
  type      = number
  default   = 80
}

variable "port_proxy_https" {
  type      = number
  default   = 443
}

variable "subnet_cidr_block" {
  type      = string
  default   = "172.16.0.0/24"
}

variable "subnet_display_name" {
  type      = string
  default   = "pihole-wireguard-subnet"
}

variable "your_home_public_ip" {
  type      = list
}

variable "reserved_public_ip" {
  type      = string
  default   = "pihole-wireguard-public-ip"
}

variable "use_reserved_public_ip" {
  type      = string
  default   = false
}

# Image

variable "operating_system" {
  type      = string
  default   = "Canonical Ubuntu"
}

variable "operating_system_version" {
  type      = string
  default   = "20.04"
}

# Instance

variable "instance_shape" {
  type      = string
  default   = "VM.Standard.A1.Flex"
}

variable "instance_display_name" {
  type      = string
  default   = "pihole-wireguard"
}

variable "instance_shape_config_baseline_ocpu_utilization" {
  type      = string
  default   = "BASELINE_1_1"
}

variable "instance_shape_config_memory_in_gbs" {
  type      = number
  default   = 6
}

variable "instance_shape_config_ocpus" {
  type      = number
  default   = 1
}

variable "instance_source_details_boot_volume_size_in_gbs" {
  type      = number
  default   = 50
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

# user data


variable "docker_compose_version" {
  type      = string
  default   = ""
}

variable "docker_network_range" {
  type      = string
  default   = "10.7.0.0/16"
}

variable "docker_compose_network_range" {
  type      = string
  default   = "10.7.107.0/24"
}

variable "pihole_ip" {
  type      = string
  default   = "10.7.107.101"
}

variable "pihole_dns_port" {
  type      = string
  default   = "53"
}

variable "pihole_web_port" {
  type      = string
  default   = "8080"
}

variable "wg_port" {
  type      = string
  default   = "51820"
}

variable "wg_keys_base64" {
  type      = string
  sensitive = true
}

variable "wg_server_private_key" {
  type      = string
  sensitive = true
}

variable "wg_server_ip" {
  type      = string
  default   = "10.6.0.1/24"
}

variable "wg_server_port" {
  type      = string
  default   = "51820"
}

variable "wg_client_public_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "wg_client_ip" {
  type      = string
  default   = "10.6.0.2/32"
}

variable "tz" {
  type      = string
  default   = "America/New_York"
}

variable "pihole_webpassword" {
  type      = string
  sensitive = true
}

variable "pihole_dns_ip" {
  type      = string
  default   = "1.1.1.1"
}
