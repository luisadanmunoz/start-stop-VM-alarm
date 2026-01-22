module "role_assignment" {
  source   = "../modules/role_assignment"
  for_each = var.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name

  principal_id = (
    can(module.automation_account[each.value.automation_account_name])
    ? module.automation_account[each.value.automation_account_name].principal_id
    : each.value.automation_account_name
  )
  depends_on = [module.rg]
}