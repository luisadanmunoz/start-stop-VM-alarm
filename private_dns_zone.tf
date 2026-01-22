# #############################################################################
# PRIVATE DNS ZONE
# #############################################################################
module "private_dns_zone" {
  source = "../modules/private_dns_zone"

  for_each = var.private_dns_zone

  name                = each.value["name"]
  resource_group_name = each.value["resource_group_name"]

  depends_on = [module.subnet]

  tags = var.tags
  # #############################################################################
  # PRIVATE DNS ZONE VNET LINK
  # #############################################################################
  name_virtual_network_link = each.value["name_virtual_network_link"]
  virtual_network_id        = element([for k, v in module.vnet : v.id if v.name == each.value["name_virtual_network"]], 0)
}