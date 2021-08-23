variable "fingerprint" {}
variable "private_key_path" {}

variable "ssh_public_key" {}

variable "tenancy_ocid" {}
variable "user_ocid" {}

variable "region" {}

variable "prom-url" {}
variable "prom-id" {}
variable "prom-pw" {}

variable "inlets-version" {
  default = "0.9.0-rc2"
}
