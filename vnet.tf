#############################################################################
# RESOURCES VIRTUAL NETWORK
#############################################################################
module "vnet" {
  source = "../modules/vnet"

  for_each = var.vnet

  name                = each.value["name"]
  location            = each.value["location"]
  resource_group_name = each.value["resource_group_name"]
  address_space       = each.value["address_space"]
  dns_servers         = each.value["dns_servers"]

  tags = var.tags

  depends_on = [module.rg]
}