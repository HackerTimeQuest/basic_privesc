#!/usr/bin/env bash
# Minimal Terraform manifest — produces a single Azure VM for HackerTime.
# Run:  cd infrastructure/terraform && terraform init && terraform apply
# Prerequisite: Azure CLI login with `az login`

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "vm_name" {
  description = "Name of the Azure VM"
  default     = "hacker-time-privesc"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  default     = "hacker-time-rg"
}

variable "location" {
  description = "Azure region for resources"
  default     = "northeurope"
}

variable "environment" {
  description = "Environment tag"
  default     = "hackertime"
}

variable "admin_username" {
  description = "Admin username for the VM"
  default     = "azureuser"
}

variable "allow_password_auth" {
  description = "Whether to allow SSH password authentication"
  type        = bool
  default     = true
}

variable "admin_password" {
  description = "Admin password for the VM"
  type        = string
  sensitive   = true
  default     = "wareh0use!"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = var.environment
    purpose     = "cyber-range"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.vm_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    environment = var.environment
  }
}

# Subnet
resource "azurerm_subnet" "main" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [azurerm_virtual_network.main]
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}

# Network Interface
resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "${var.vm_name}-ip-config"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }

  tags = {
    environment = var.environment
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Public IP Address
resource "azurerm_public_ip" "main" {
  name                = "${var.vm_name}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = var.environment
  }
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "target" {
  name                = var.vm_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B1s"

  admin_username = var.admin_username

  # Toggle password authentication (lab requires password auth)
  disable_password_authentication = !var.allow_password_auth

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  # If password auth is allowed, supply the admin password (from Key Vault or variable)
  admin_password = var.admin_password

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  # Custom Script Extension to apply cloud-init
  custom_data = base64encode(file("${path.module}/../cloud-init/basic-privesc.yaml"))

  tags = {
    environment = var.environment
    purpose     = "cyber-range"
  }
}

# Outputs
output "vm_id" {
  description = "The ID of the created VM"
  value       = azurerm_linux_virtual_machine.target.id
}

output "public_ip_address" {
  description = "The public IP address of the VM"
  value       = azurerm_public_ip.main.ip_address
}

output "private_ip_address" {
  description = "The private IP address of the VM"
  value       = azurerm_network_interface.main.private_ip_address
}

output "resource_group_name" {
  description = "The resource group name"
  value       = azurerm_resource_group.main.name
}
