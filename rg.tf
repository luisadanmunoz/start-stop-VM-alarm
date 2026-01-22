#############################################################################
# RESOURCE GROUPS
#############################################################################
module "rg" {
  source = "../modules/rg"

  for_each = var.rg

  resource_group_name = each.value["resource_group_name"]
  location            = each.value["location"]

  tags = var.tags
}