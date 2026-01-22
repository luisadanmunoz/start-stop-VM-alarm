module "automation_runbook" {
  source   = "../modules/automation_runbook"
  for_each = var.automation_runbooks

  name                    = each.key
  resource_group_name     = each.value.resource_group_name
  location                = each.value.location
  automation_account_name = each.value.automation_account_name
  runbook_type            = each.value.runbook_type

  publish_content_link_uri = try(each.value.publish_content_link_uri, null)

  # Ternario en UNA sola línea (evita el error de parsing)
  content = (try(each.value.publish_content_link_uri, null) != null) ? null : trimspace(file("${path.root}/${each.value.script_path}"))

  description              = each.value.description
  log_progress             = each.value.log_progress
  log_verbose              = each.value.log_verbose
  log_activity_trace_level = each.value.log_activity_trace_level
  tags                     = var.tags

  depends_on = [module.role_assignment, module.automation_account]
}

