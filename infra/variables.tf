variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-az-deployment"
}

variable "jump_vm_admin_username" {
  description = "Admin username for the jump VM"
  type        = string
  default     = "azureuser"
}

variable "jump_vm_ssh_public_key" {
  description = "SSH public key content for the jump VM"
  type        = string
}
