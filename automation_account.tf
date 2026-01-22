module "automation_account" {
  source   = "../modules/automation_account"
  for_each = var.automation_accounts

  automation_account_name       = each.key
  resource_group_name           = each.value.resource_group_name
  location                      = each.value.location
  sku_name                      = each.value.sku_name
  identity_type                 = each.value.identity_type
  public_network_access_enabled = each.value.public_network_access_enabled
  subnet_id                     = element([for k, v in module.subnet : v.id if v.name == each.value["subnet"]], 0)
  private_dns_zone_ids          = element([for k, v in module.private_dns_zone : v.id if v.name == each.value["private_dns_zone_ids"]], 0)
  tags                          = var.tags

}