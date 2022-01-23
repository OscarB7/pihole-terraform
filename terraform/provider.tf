terraform {
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = ">= 4.57.0"
    }
  }
  required_version = ">= 1.0.11"
}

provider "oci" {
  tenancy_ocid = var.oci_tenancy_ocid
  user_ocid    = var.oci_user_ocid
  private_key  = base64decode(var.oci_private_key_base64)
  fingerprint  = var.oci_fingerprint
  region       = var.oci_region
}
