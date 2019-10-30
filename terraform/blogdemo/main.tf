######################### VARIABLES & DATA ###############################

variable "vcenter_server" { type = "string" }
variable "vcenter_user" { type = "string" }
variable "vcenter_pass" { type = "string" }
variable "vcenter_folder" { type = "string" }
variable "vcenter_datacenter" { type = "string" }
variable "vcenter_datastore" { type = "string" }
variable "vcenter_rpool" { type = "string" }
variable "vcenter_network" { type = "string" }
variable "vcenter_template" { type = "string" }
variable "kube_count" { type = "string" }
variable "kube_subnet" { type = "string" }
variable "ssh_key_private" { type = "string" }

provider "vsphere" {
  user           = "${var.vcenter_user}"
  password       = "${var.vcenter_pass}"
  vsphere_server = "${var.vcenter_server}"
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.vcenter_datacenter}"
}

data "vsphere_datastore_cluster" "datastore_cluster" {
  name          = "${var.vcenter_datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.vcenter_rpool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.vcenter_network}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name = "${var.vcenter_template}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

######################## KUBE WORKER NODES ##################################

resource "vsphere_virtual_machine" "kubevm" {
  count                = "${var.kube_count}"
  name                 = "kubew${count.index+1}"
  resource_pool_id     = "${data.vsphere_resource_pool.pool.id}"
  datastore_cluster_id = "${data.vsphere_datastore_cluster.datastore_cluster.id}"
  folder               = "${var.vcenter_folder}"
  num_cpus             = 4
  memory               = 8192
  memory_reservation   = 8192
  guest_id             = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type            = "${data.vsphere_virtual_machine.template.scsi_type}"
  annotation           = "Kubernetes Node - Created by Terraform - OzanOrcunus"

  wait_for_guest_net_timeout = 0
  boot_delay                 = 1000
  enable_disk_uuid           = false

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }
  disk {
    label            = "disk-root"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    customize {
      linux_options {
        host_name = "kubew${count.index+1}"
        domain    = "orcunuso.demo"
        time_zone = "Europe/Istanbul"
      }
      network_interface {
        ipv4_address = "${var.kube_subnet}.${count.index+71}"
        ipv4_netmask = 24
      }

      ipv4_gateway    = "${var.kube_subnet}.1"
      dns_server_list = [ "192.168.1.11" , "192.168.1.12" ]
      dns_suffix_list = [ "orcunus.demo" ]
    }
  }
  connection {
    type        = "ssh"
    user        = "root"
    host        = "${var.kube_subnet}.${count.index+71}"
    private_key = "${file(var.ssh_key_private)}"
  }
  provisioner "remote-exec" {
    inline = ["echo xxxxxxxxxxxxxxxxxxxxx `hostname`: SERVER IS UP AND RUNNING xxxxxxxxxxxxxxxxxxxxx"]
  }
}

locals {
  inventory_kubevm = "${join(",", vsphere_virtual_machine.kubevm.*.clone.0.customize.0.network_interface.0.ipv4_address)}"
}

resource "null_resource" "inventory_kubevm" {
  triggers = {
    vm_ids = "${join(",", vsphere_virtual_machine.kubevm.*.id)}"
  }
  provisioner "local-exec" {
    command = "echo ${local.inventory_kubevm}; ansible-playbook -i ${local.inventory_kubevm}, ansible_ospatch.yaml"
  }
}

