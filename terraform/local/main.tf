
#--- PROVIDER

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

#--- SET DISK and GET ISO IMAGE

resource "libvirt_pool" "disks" {
  name = "disks"
  type = "dir"
  target {
    path = "/mnt/kvm/disks"
  }
}

# Fetch the ubuntu image
resource "libvirt_volume" "base_volume" {
  name = "${var.hostname}-base_volume.qcow2"
  pool = "disks"
  source = "./assets/jammy-server-cloudimg-amd64.img"
  depends_on = [libvirt_pool.disks]
}

resource "libvirt_volume" "volume" {
  name = "${var.hostname}-volume.qcow2"
  pool = "disks"
  base_volume_name = "${var.hostname}-base_volume.qcow2"
  size = 17179869184 # disk size in bytes, defaults to 16 GB
  depends_on = [libvirt_pool.disks, libvirt_volume.base_volume]
}

#--- CUSTOMIZE ISO IMAGE

# 1a. Retrieve our local cloud_init.cfg and update its content (= add ssh-key) using variables
data "template_file" "user_data" {
  template = file("${path.module}/assets/cloud_init.cfg")
  vars = {
    hostname = var.hostname
    fqdn = "${var.hostname}.${var.domain}"
    public_key = file("${path.module}/.ssh/id_rsa.pub")
  }
}

# 1b. Save the result as init.cfg
data "template_cloudinit_config" "config" {
  gzip = false
  base64_encode = false
  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = "${data.template_file.user_data.rendered}"
  }
}

# 2. Retrieve our network_config
data "template_file" "network_config" {
  template = file("${path.module}/assets/network_config_${var.ip_type}.cfg")
}

# 3. Add ssh-key and network config to the instance
resource "libvirt_cloudinit_disk" "commoninit" {
  name = "${var.hostname}-commoninit.iso"
  pool = "default"
  user_data      = data.template_cloudinit_config.config.rendered
  network_config = data.template_file.network_config.rendered
}

#--- CREATE VM

resource "libvirt_domain" "domain-ubuntu" {
  name = "${var.hostname}"
  memory = var.memoryMB
  vcpu = var.cpu

  disk {
    volume_id = libvirt_volume.volume.id
  }

  network_interface {
    network_name = "host-bridge"
    # bridge = "br0"
    # network_name = "default"
    # wait_for_lease = true # Work only with default network
  }

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  # Ubuntu can hang is a isa-serial is not present at boot time.
  # If you find your CPU 100% and never is available this is why
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type = "spice"
    listen_type = "address"
    autoport = "true"
  }
}
