#############################################################################
# RESOURCES SUBNET
#############################################################################
module "subnet" {
  source = "../modules/subnet"

  for_each = var.subnet
  #############################################################################
  # SUBNET
  #############################################################################
  name                  = each.value["name"]
  resource_group_name   = each.value["resource_group_name"]
  virtual_network_name  = each.value["virtual_network_name"]
  address_prefixes      = each.value["address_prefixes"]
  use_service_endpoints = each.value["use_service_endpoints"]
  service_endpoints     = each.value["service_endpoints"]
  //default_outbound_access_enabled  = each.value ["default_outbound_access_enabled"] # Habilite el acceso saliente predeterminado a Internet para la subred.
  #############################################################################
  # DYNAMIC BLOCKS SUBNET DELEGATION
  #############################################################################
  enable_delegation       = each.value["enable_delegation"]
  name_delegation         = each.value["name_delegation"]
  name_service_delegation = each.value["name_service_delegation"]
  use_actions             = each.value["use_actions"]
  actions                 = each.value["actions"]
  /*
  #############################################################################
  # SUBNET NSG ASSOCIATION
  #############################################################################
  nsg_assoc = each.value["nsg_assoc"]
  nsg_id    = length([for k, v in module.nsg : v.nsg_id if v.nsg_name == each.value["nsg"]]) > 0 ? element([for k, v in module.nsg : v.nsg_id if v.nsg_name == each.value["nsg"]], 0) : null
  #############################################################################
  # SUBNET ROUTE TABLE ASSOCIATION
  #############################################################################
  route_table_assoc = each.value["route_table_assoc"]
  route_table_id    = length([for k, v in module.route_table : v.id if v.name == each.value["route_table_name"]]) > 0 ? element([for k, v in module.route_table : v.id if v.name == each.value["route_table_name"]], 0) : null
*/
  depends_on = [module.vnet]
}