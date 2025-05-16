
output "vm_NIC_info" {
  value = libvirt_domain.domain-ubuntu.network_interface
  description = "IP addresses of the created VMs. If not showed run nmap on your subnet."
}

output "vm_name" {
  value = libvirt_domain.domain-ubuntu.name
  description = "Name of the created VMs"
} 