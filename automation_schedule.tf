module "automation_schedule" {
  source   = "../modules/automation_schedule"
  for_each = var.automation_schedule

  name                    = each.value.name
  resource_group_name     = each.value.resource_group_name
  automation_account_name = each.value.automation_account_name

  frequency = each.value.frequency
  interval  = each.value.interval

  vm_start_schedule_start_time  = each.value.vm_start_schedule_start_time
  vm_start_schedule_description = each.value.vm_start_schedule_description
  vm_start_schedule_timezone    = each.value.vm_start_schedule_timezone

  runbook_name = each.value.runbook_name

  tag_key   = each.value.tag_key
  tag_value = each.value.tag_value

  depends_on = [
    module.automation_account,
    module.role_assignment,
    module.automation_runbook
  ]
}
