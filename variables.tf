#############################################################################
# VARIABLES
#############################################################################
variable "rg" {
  default = {}
}
variable "tags" {
  default = {}
}
variable "role_assignments" {
  default = {}
}
variable "automation_runbooks" {
  description = "Runbooks a crear"
  type = map(object({
    resource_group_name     = string
    location                = string
    automation_account_name = string
    runbook_type            = string

    # uno de los dos
    script_path              = optional(string) # relativo al root
    publish_content_link_uri = optional(string)

    description              = optional(string, "")
    log_progress             = optional(bool, true)
    log_verbose              = optional(bool, true)
    log_activity_trace_level = optional(number, 0)
    tags                     = optional(map(string), {})
  }))
  default = {}
}
variable "automation_accounts" {
  default = {}
}
variable "automation_schedule" {
  default = {}
}
variable "vnet" {
  default = {}
  
}
variable "subnet" {
  default = {}
}
variable "private_dns_zone" {
  default = {}
}
variable "storage_accounts" {
  default = {}
}
variable "function_app" {
  default = {}
}
variable "monitor_action_group" {
  default = {}
}
variable "log_analytics" {
  default = {}
}
variable "monitor_scheduled_query_rules_alert_v2" {
  default = {}
}

