terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.23.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.5.3"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "aws" {
  region = var.region
}

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "azurerm_resource_group" "tfe" {
  name     = var.tag_prefix
  location = "North Europe"
}

resource "azurerm_virtual_network" "tfe" {
  name                = "${var.tag_prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name
}

resource "azurerm_subnet" "public1" {
  name                 = "${var.tag_prefix}-public1"
  resource_group_name  = azurerm_resource_group.tfe.name
  virtual_network_name = azurerm_virtual_network.tfe.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 1)]
}

resource "azurerm_subnet" "private1" {
  name                 = "${var.tag_prefix}-private1"
  resource_group_name  = azurerm_resource_group.tfe.name
  virtual_network_name = azurerm_virtual_network.tfe.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 11)]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private2" {
  name                 = "${var.tag_prefix}-private2"
  resource_group_name  = azurerm_resource_group.tfe.name
  virtual_network_name = azurerm_virtual_network.tfe.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 2)]
}

resource "azurerm_subnet" "private3" {
  name                 = "${var.tag_prefix}-private3"
  resource_group_name  = azurerm_resource_group.tfe.name
  virtual_network_name = azurerm_virtual_network.tfe.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 3)]
}

resource "azurerm_network_security_group" "tfe" {
  name                = "${var.tag_prefix}-nsg"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name

  security_rule {
    name                       = "https"
    priority                   = "100"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "http"
    priority                   = "110"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ssh"
    priority                   = "120"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "postgresql"
    priority                   = "130"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                   = "vault-internal"
    priority               = "140"
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "8201"
    #source_address_prefix      = var.vnet_cidr
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "redis-ssl"
    priority                   = "150"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6380"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "redis-non-ssl"
    priority                   = "160"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6379"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

}

resource "azurerm_subnet_network_security_group_association" "tfe-public1" {
  subnet_id                 = azurerm_subnet.public1.id
  network_security_group_id = azurerm_network_security_group.tfe.id
}

resource "azurerm_subnet_network_security_group_association" "tfe-private1" {
  subnet_id                 = azurerm_subnet.private1.id
  network_security_group_id = azurerm_network_security_group.tfe.id
}

resource "azurerm_subnet_network_security_group_association" "tfe-private2" {
  subnet_id                 = azurerm_subnet.private2.id
  network_security_group_id = azurerm_network_security_group.tfe.id
}

resource "azurerm_subnet_network_security_group_association" "tfe-private3" {
  subnet_id                 = azurerm_subnet.private3.id
  network_security_group_id = azurerm_network_security_group.tfe.id
}

resource "azurerm_public_ip" "tfe" {
  name                = "${var.tag_prefix}-nat-publicIP"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}


resource "azurerm_nat_gateway" "tfe" {
  name                    = "${var.tag_prefix}-nat-Gateway"
  location                = azurerm_resource_group.tfe.location
  resource_group_name     = azurerm_resource_group.tfe.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
}

resource "azurerm_nat_gateway_public_ip_association" "tfe" {
  nat_gateway_id       = azurerm_nat_gateway.tfe.id
  public_ip_address_id = azurerm_public_ip.tfe.id
}

resource "azurerm_subnet_nat_gateway_association" "tfe_private1" {
  subnet_id      = azurerm_subnet.private1.id
  nat_gateway_id = azurerm_nat_gateway.tfe.id
}

resource "azurerm_subnet_nat_gateway_association" "tfe_private2" {
  subnet_id      = azurerm_subnet.private2.id
  nat_gateway_id = azurerm_nat_gateway.tfe.id
}

resource "azurerm_private_dns_zone" "example" {
  name                = "${var.tag_prefix}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.tfe.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = var.tag_prefix
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = azurerm_virtual_network.tfe.id
  resource_group_name   = azurerm_resource_group.tfe.name
}

resource "azurerm_postgresql_flexible_server" "example" {
  name                          = "${var.tag_prefix}-psqlflexibleserver"
  resource_group_name           = azurerm_private_dns_zone_virtual_network_link.example.resource_group_name
  location                      = azurerm_resource_group.tfe.location
  version                       = "15"
  delegated_subnet_id           = azurerm_subnet.private1.id
  private_dns_zone_id           = azurerm_private_dns_zone.example.id
  administrator_login           = var.postgres_user
  administrator_password        = var.postgres_password
  zone                          = "1"
  public_network_access_enabled = false

  storage_mb = 32768

  sku_name = "GP_Standard_D2s_v3"
}

resource "azurerm_postgresql_flexible_server_database" "example" {
  name      = "tfe"
  server_id = azurerm_postgresql_flexible_server.example.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "example" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.example.id
  value     = "CITEXT,HSTORE,UUID-OSSP"
}

resource "azurerm_storage_account" "example" {
  name                     = var.storage_account
  resource_group_name      = azurerm_resource_group.tfe.name
  location                 = azurerm_resource_group.tfe.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  routing {
    publish_microsoft_endpoints = true
    choice                      = "MicrosoftRouting"
  }

}

resource "azurerm_storage_container" "example" {
  name                  = "${var.tag_prefix}-container"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}

resource "azurerm_public_ip" "client" {
  name                = "${var.tag_prefix}-client-publicIP"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_network_interface" "client" {
  name                = "${var.tag_prefix}-client"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name

  ip_configuration {
    name                          = "public_interface"
    subnet_id                     = azurerm_subnet.public1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.client.id
  }
}


resource "azurerm_linux_virtual_machine" "client" {
  name                = "${var.tag_prefix}-client"
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  size                = "Standard_D4s_v3"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.client.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "22.04.202312060"
  }
}

resource "azurerm_public_ip" "tfe_lb" {
  name                = "${var.tag_prefix}-tfe-publicIP"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_lb" "tfe_lb" {
  name                = "${var.tag_prefix}-tfe-lb"
  location            = azurerm_resource_group.tfe.location
  resource_group_name = azurerm_resource_group.tfe.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "${var.tag_prefix}-fip"
    public_ip_address_id = azurerm_public_ip.tfe_lb.id
  }
}

resource "azurerm_lb_probe" "http80" {
  loadbalancer_id = azurerm_lb.tfe_lb.id
  name            = "${var.tag_prefix}-health80"
  port            = 80
}

resource "azurerm_lb_probe" "https443" {
  loadbalancer_id = azurerm_lb.tfe_lb.id
  name            = "${var.tag_prefix}-health443"
  port            = 443
}

resource "azurerm_lb_rule" "http80" {
  loadbalancer_id                = azurerm_lb.tfe_lb.id
  name                           = "${var.tag_prefix}-http80"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.tfe_lb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.tfe_lb_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http80.id
}

resource "azurerm_lb_rule" "https443" {
  loadbalancer_id                = azurerm_lb.tfe_lb.id
  name                           = "${var.tag_prefix}-https443"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = azurerm_lb.tfe_lb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.tfe_lb_backend_pool.id]
  probe_id                       = azurerm_lb_probe.https443.id
}

resource "azurerm_lb_backend_address_pool" "tfe_lb_backend_pool" {
  loadbalancer_id = azurerm_lb.tfe_lb.id
  name            = "${var.tag_prefix}-backendpool"
}

resource "azurerm_redis_cache" "tfe" {
  name                      = "${var.tag_prefix}-redis"
  location                  = azurerm_resource_group.tfe.location
  resource_group_name       = azurerm_resource_group.tfe.name
  capacity                  = 1
  family                    = "P"
  sku_name                  = "Premium"
  non_ssl_port_enabled      = true
  minimum_tls_version       = "1.2"
  private_static_ip_address = cidrhost(cidrsubnet(var.vnet_cidr, 8, 3), 22)
  subnet_id                 = azurerm_subnet.private3.id
  redis_version             = 6

  redis_configuration {
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "tfe" {
  name                = "${var.tag_prefix}-tfe-vmss"
  resource_group_name = azurerm_resource_group.tfe.name
  location            = azurerm_resource_group.tfe.location
  sku                 = "Standard_D4s_v3"
  instances           = var.number_tfe_instances
  admin_username      = "adminuser"

  admin_ssh_key {
    username   = "adminuser"
    public_key = var.public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "22.04.202312060"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  network_interface {
    name    = "${var.tag_prefix}-tfe-nic"
    primary = true

    ip_configuration {
      name                                   = "private_interface"
      subnet_id                              = azurerm_subnet.private2.id
      primary                                = true
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.tfe_lb_backend_pool.id]
    }
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/cloudinit_tfe_server.yaml", {
    tag_prefix               = var.tag_prefix
    dns_hostname             = var.dns_hostname
    tfe_username             = var.tfe_username
    tfe_password             = var.tfe_password
    postgres_user            = var.postgres_user
    postgres_fqdn            = azurerm_postgresql_flexible_server.example.fqdn
    redis_host               = azurerm_redis_cache.tfe.hostname
    redis_port               = azurerm_redis_cache.tfe.port
    redis_primary_access_key = azurerm_redis_cache.tfe.primary_access_key
    dns_zonename             = var.dns_zonename
    postgres_password        = var.postgres_password
    tfe_release              = var.tfe_release
    tfe_license              = var.tfe_license
    certificate_email        = var.certificate_email
    full_chain               = base64encode("${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}")
    private_key_pem          = base64encode(acme_certificate.certificate.private_key_pem)
    container_name           = azurerm_storage_container.example.name
    storage_account          = azurerm_storage_account.example.name
    storage_account_key      = azurerm_storage_account.example.primary_access_key
  }))

}

data "azurerm_virtual_machine_scale_set" "tfe" {
  name                = azurerm_linux_virtual_machine_scale_set.tfe.name
  resource_group_name = azurerm_resource_group.tfe.name
}
