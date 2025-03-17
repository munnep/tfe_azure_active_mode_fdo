data "aws_route53_zone" "selected" {
  name         = var.dns_zonename
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${var.dns_hostname}.${var.dns_zonename}"
  type    = "A"
  ttl     = "300"
  #records = [azurerm_public_ip.tfe_instance.ip_address]
  records = [azurerm_public_ip.tfe_lb.ip_address]
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.certificate_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = "${var.dns_hostname}.${var.dns_zonename}"

  dns_challenge {
    provider = "route53"

    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.selected.zone_id
    }
  }
}