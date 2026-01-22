module "monitor_scheduled_query_rules_alert_v2" {
  source   = "../modules/monitor_scheduled_query_rules_alert_v2"
  for_each = var.monitor_scheduled_query_rules_alert_v2

    name                            = each.key
    resource_group_name             = each.value.resource_group_name
    location                        = each.value.location
    scopes_id                       = element([for k, v in module.log_analytics : v.id if v.name == each.value["law_id"]], 0)
    severity                        = each.value.severity
    evaluation_frequency            = each.value.evaluation_frequency
    window_duration                 = each.value.window_duration
    time_aggregation_method         = each.value.time_aggregation_method
    operator                        = each.value.operator
    threshold                       = each.value.threshold
    minimum_failing_periods_to_trigger_alert = each.value.minimum_failing_periods_to_trigger_alert
    number_of_evaluation_periods    = each.value.number_of_evaluation_periods
    action_group_id                 = element([for k, v in module.monitor_action_group : v.id if v.name == each.value["action_group_id"]], 0)
    tags                            = var.tags
}