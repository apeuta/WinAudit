provider "azurerm" {
  subscription_id = var.subscriptionID

  features {}
}

#Create a Resource Group
resource "azurerm_resource_group" "auditRG" {
  name                = var.resourceGroupName
  location            = var.location
}

#Create Network Security Group
resource "azurerm_network_security_group" "auditSG" {
  name                = var.securityGroup
  location            = var.location
  resource_group_name = var.resourceGroupName
}

#Create Rule to Allow RDP Inbound
resource "azurerm_network_security_rule" "rdp" {
  name                        = "rdp-access"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resourceGroupName
  network_security_group_name = var.securityGroup
}

#Create VN within RG
resource "azurerm_virtual_network" "auditVN" {
  name                  = var.virtualNetwork
  address_space         = ["10.0.0.0/16"]
  location              = var.location
  resource_group_name   = var.resourceGroupName
}

#Create Subnets
resource "azurerm_subnet" "subnet-1" {
  name                  = "audit-subnet-1"
  resource_group_name   = var.resourceGroupName
  virtual_network_name  = var.virtualNetwork
  address_prefix        = "10.0.1.0/24"
}

#Associate Subnet with NSG
resource "azurerm_subnet_network_security_group_association" "test" {
  subnet_id                 = "${azurerm_subnet.subnet-1.id}"
  network_security_group_id = "${azurerm_network_security_group.auditSG.id}"
}

#Create Public IP
resource "azurerm_public_ip" "dataip" {
  name                          = "testPublicIP"
  location                      = var.location
  resource_group_name           = var.resourceGroupName
  allocation_method             = "Dynamic"
}

#Create Network Interface
resource "azurerm_network_interface" "vm_interface" {
  name                  = "vm_NIC"
  location              = var.location
  resource_group_name   = var.resourceGroupName
  ip_configuration {
    name                            = "Server2019"
    subnet_id                       = "${azurerm_subnet.subnet-1.id}"
    private_ip_address_allocation   = "dynamic"
    public_ip_address_id            = "${azurerm_public_ip.dataip.id}"
  }
}

#Create a VM
resource "azurerm_virtual_machine" "windows" {
  name                              = "APWindows"
  location                          = var.location
  resource_group_name               = var.resourceGroupName
  network_interface_ids             = ["${azurerm_network_interface.vm_interface.id}"]
  vm_size                           = "Standard_DS1_v2"
  delete_os_disk_on_termination     = "true"
  delete_data_disks_on_termination   = "true"

  storage_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  storage_os_disk {
    name = "disk4APWindows"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name = "APserver2019"
    admin_username = var.vm_admin
    admin_password = var.vm_pass
  }

  os_profile_windows_config {
    provision_vm_agent        = "true"
    enable_automatic_upgrades = "true"
    winrm {
    protocol = "http"
    certificate_url = ""
    }
  }
}

#Retrieve Public IP
data "azurerm_public_ip" "test" {
  name = "${azurerm_public_ip.dataip.name}"
  resource_group_name = var.resourceGroupName
  depends_on = [azurerm_virtual_machine.windows]
}
output "public_ip_address" {
  value = "${data.azurerm_public_ip.test.ip_address}"
}
