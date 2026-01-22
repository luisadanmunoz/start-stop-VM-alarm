module "monitor_action_group" {
  source   = "../modules/monitor_action_group"
  for_each = var.monitor_action_group

    name                            = each.key
    resource_group_name             = each.value.resource_group_name
    short_name                      = each.value.short_name
    email_receiver_name             = each.value.email_receiver_name
    email_receiver_email_address    = each.value.email_receiver_email_address
    automation_account_name         = element([for k, v in module.automation_account : v.name if v.name == each.value["automation_account_name"]], 0)
    tags                            = var.tags

    depends_on = [module.rg]
}