resource "random_pet" "server" {}

resource "random_password" "password" {
  length = 64
  special = false
  lower = true
  upper = true
}
resource "random_integer" "dns" {
  max = 9999
  min = 1000
}

locals {
  pet_name = random_pet.server.id
  dns_label = random_integer.dns.id
  auth_token = random_password.password.result
  shape = "VM.Standard.E2.1.Micro"
}

resource "oci_identity_compartment" "inlets-exit-node" {
  description = "OCI compartment for the inlets exit node"
  name = "inlets-exit-node"
}

data "oci_identity_availability_domains" "inlets-availability-domains" {
  compartment_id = oci_identity_compartment.inlets-exit-node.id
}

data "oci_core_images" "ubuntu-minimal" {
  operating_system = "Canonical Ubuntu"
  operating_system_version = "20.04"
  sort_by = "TIMECREATED"
  sort_order = "DESC"
  compartment_id = oci_identity_compartment.inlets-exit-node.id
  shape = local.shape
}

resource "oci_core_vcn" "inlets-vcn" {
  cidr_block = "10.0.0.0/16"
  compartment_id = oci_identity_compartment.inlets-exit-node.id
  dns_label = format("vnc%s", local.dns_label)
  display_name = "inlets-vcn"
  depends_on = [
    oci_identity_compartment.inlets-exit-node
  ]
}

resource "oci_core_subnet" "inlets-subnet" {
  cidr_block = "10.0.0.0/24"
  compartment_id = oci_identity_compartment.inlets-exit-node.id
  vcn_id = oci_core_vcn.inlets-vcn.id
  security_list_ids = [
    oci_core_security_list.inlets-sec-list.id,
    oci_core_vcn.inlets-vcn.default_security_list_id
  ]
  route_table_id = oci_core_vcn.inlets-vcn.default_route_table_id
  dhcp_options_id = oci_core_vcn.inlets-vcn.default_dhcp_options_id
  dns_label = format("subnet%s", local.dns_label)
}

resource "oci_core_internet_gateway" "inlets-internet-gateway" {
  compartment_id = oci_identity_compartment.inlets-exit-node.id
  vcn_id = oci_core_vcn.inlets-vcn.id
}

resource "oci_core_security_list" "inlets-sec-list" {
  display_name = "inlets-sec-list"
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol = "all"
  }
  ingress_security_rules {
    protocol = "6"
    source = "0.0.0.0/0"
    stateless = false
    tcp_options {
      max = 22
      min = 22
      source_port_range {
        min = 1
        max = 65535
      }
    }
  }
  ingress_security_rules {
    protocol = "6"
    source = "0.0.0.0/0"
    stateless = false
    tcp_options {
      max = 8123
      min = 8123
      source_port_range {
        min = 1
        max = 65535
      }
    }
  }
  compartment_id = oci_identity_compartment.inlets-exit-node.id
  vcn_id = oci_core_vcn.inlets-vcn.id
}

resource "oci_core_default_route_table" "inlets-route-table" {
  manage_default_resource_id = oci_core_vcn.inlets-vcn.default_route_table_id
  route_rules {
    network_entity_id = oci_core_internet_gateway.inlets-internet-gateway.id
    destination = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}


resource "oci_core_instance" "inlets-ubuntu-instance" {
  availability_domain = data.oci_identity_availability_domains.inlets-availability-domains.availability_domains[0].name
  compartment_id = oci_identity_compartment.inlets-exit-node.id
  shape = local.shape
  source_details {
    source_id = data.oci_core_images.ubuntu-minimal.images[0].id
    source_type = "image"
  }

  display_name = local.pet_name
  create_vnic_details {
    assign_public_ip = true
    subnet_id = oci_core_subnet.inlets-subnet.id
  }
  metadata = {
    user_data = base64encode(templatefile("${path.module}/startup/startup.sh", {
      authToken = local.auth_token,
      version = var.inlets-version
      promUrl = var.prom-url
      promId = var.prom-id
      promPW = var.prom-pw
    }))
    ssh_authorized_keys = file(var.ssh_public_key)
  }
  preserve_boot_volume = false
}

output "inlets-connection-string" {
  value = "inlets-pro tcp client --url wss://${oci_core_instance.inlets-ubuntu-instance.public_ip}:8123 --token ${local.auth_token} --upstream $UPSTREAM --ports $PORTS"
  sensitive = true
}