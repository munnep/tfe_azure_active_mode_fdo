variable "tag_prefix" {
  description = "default prefix of names"
}

variable "vnet_cidr" {
  description = "which private subnet do you want to use for the VPC. Subnet mask of /16"
}

variable "postgres_user" {
  description = "postgresql user"
}

variable "public_key" {
  type        = string
  description = "public to use on the instances"
}

variable "postgres_password" {
  description = "password postgresql user"
}

variable "subscription_id" {
  description = "Azure Subscription ID"
}


variable "storage_account" {
  description = "name of the storage account"
}

variable "tfe_username" {
  description = "username for tfe admin user"
  default = "admin"
}

variable "tfe_password" {
  description = "password for tfe admin user"
}

variable "dns_hostname" {
  type        = string
  description = "DNS name you use to access the website"
}

variable "dns_zonename" {
  type        = string
  description = "DNS zone the record should be created in"
}

variable "tfe_release" {
  description = "Which release version of TFE to install"
}

variable "tfe_license" {
  description = "the TFE license as a string"
}

variable "region" {
  description = "region to create the environment"
}

variable "certificate_email" {
  description = "email address to register the certificate"
}

variable "number_tfe_instances" {
  description = "Number of TFE instances in the VM Scale Set"
}