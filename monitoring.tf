# Azure Monitor Module for Web Apps and Front Door Monitoring

## Application Insights (centralized in monitoring RG)
resource "azapi_resource" "site-appinsights" { # kept logical name for minimal downstream change
  type      = "Microsoft.Insights/components@2020-02-02"
  name      = local.app_insights_name_effective
  parent_id = azapi_resource.site-groupmon.id
  location  = azapi_resource.site-groupmon.location

  body = {
    kind = "web"
    properties = {
      Application_Type    = "web"
      WorkspaceResourceId = azapi_resource.site-loganalytics-workspace.id
      IngestionMode       = "LogAnalytics"
    }
  }

  tags = merge(local.merged_tags, { purpose = "application-monitoring" })
}

## Log Analytics Workspace (centralized)
resource "azapi_resource" "site-loganalytics-workspace" { # keep logical reference name
  type      = "Microsoft.OperationalInsights/workspaces@2022-10-01"
  name      = local.log_analytics_workspace_name_effective
  parent_id = azapi_resource.site-groupmon.id
  location  = azapi_resource.site-groupmon.location

  body = {
    properties = {
      sku = {
        name = "PerGB2018"
      }
      retentionInDays = 30
      features = {
        enableLogAccessUsingOnlyResourcePermissions = true
      }
    }
  }

  tags = merge(local.merged_tags, { purpose = "log-analytics" })
}

## Action Group (dynamic email receivers)
resource "azapi_resource" "site-action-group" {
  type      = "Microsoft.Insights/actionGroups@2023-01-01"
  name      = local.action_group_name_effective
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      groupShortName = substr(replace(local.action_group_name_effective, "-", ""), 0, 12)
      enabled        = true
      emailReceivers = [for r in var.alert_email_receivers : {
        name                 = r.name
        emailAddress         = r.email
        useCommonAlertSchema = true
      }]
      smsReceivers           = []
      webhookReceivers       = []
      itsmReceivers          = []
      azureAppPushReceivers  = []
      voiceReceivers         = []
      logicAppReceivers      = []
      azureFunctionReceivers = []
      armRoleReceivers       = []
      eventHubReceivers      = []
    }
  }

  tags = merge(local.merged_tags, { purpose = "alert-actions" })
}

# =============================================================================
# WEB APP MONITORING ALERTS
# =============================================================================

# Web App Monitoring - CPU Usage Alert (>80% sustained)
locals {
  webapps = {
    drupalservice   = azapi_resource.drupal_app.id
    frontendservice = azapi_resource.frontend_app.id
  }
}

# Web App Monitoring - Memory Usage Alert (>80% sustained)

# Set your memory threshold in MB (per instance). Tune per SKU.
## webapp_memory_threshold_mb variable moved to variables.tf
resource "azapi_resource" "site_webapp_memory_alert" {
  for_each  = local.webapps
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-${each.key}-memory-80-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description = "Alert when ${each.key} MemoryWorkingSet exceeds ${var.webapp_memory_threshold_mb} MB (avg over 15m)"
      severity    = 2
      enabled     = true

      # Single resource scope (multi-resource not supported for Microsoft.Web/sites)
      scopes = [each.value]

      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"

      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "MemoryWorkingSet high"
            metricNamespace = "Microsoft.Web/sites" # explicit namespace
            metricName      = "MemoryWorkingSet"    # bytes
            timeAggregation = "Average"
            operator        = "GreaterThan"
            threshold       = var.webapp_memory_threshold_mb * 1024 * 1024
            criterionType   = "StaticThresholdCriterion"
            dimensions      = [] # or filter by Instance if desired
          }
        ]
      }

      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "memory-monitoring" })
}

# Web App Monitoring - HTTP 5xx Errors Alert (500, 503)
resource "azapi_resource" "site_webapp_5xx_alert" {
  for_each  = local.webapps
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-${each.key}-5xx-errors-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description = "Alert when ${each.key} HTTP 5xx errors exceed threshold"
      severity    = 1
      enabled     = true

      # Single resource scope (multi-resource unsupported for Microsoft.Web/sites)
      scopes = [each.value]

      evaluationFrequency = "PT1M"
      windowSize          = "PT5M"

      # For single-resource alerts, omit targetResourceType/Region
      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "HTTP 5xx Errors > 0"
            metricNamespace = "Microsoft.Web/sites"
            metricName      = "Http5xx"
            timeAggregation = "Total"
            operator        = "GreaterThan"
            threshold       = 0
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }

      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "http-errors-monitoring" })
}

# Web App Monitoring - Response Time Alert (>1s average)

## webapp_response_time_threshold_ms variable moved to variables.tf

resource "azapi_resource" "site_webapp_response_time_alert" {
  for_each  = local.webapps
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-${each.key}-response-time-1s-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description = "Alert when ${each.key} average response time > ${var.webapp_response_time_threshold_ms} ms"
      severity    = 2
      enabled     = true

      scopes = [each.value]

      evaluationFrequency = "PT5M"
      windowSize          = "PT15M" # <-- valid value (PT10M is invalid)

      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "Response Time > threshold"
            metricNamespace = "Microsoft.Web/sites"
            metricName      = "AverageResponseTime" # milliseconds
            timeAggregation = "Average"
            operator        = "GreaterThan"
            threshold       = var.webapp_response_time_threshold_ms
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }

      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "response-time-monitoring" })
}

# Web App Monitoring - Unexpected Restart Events Alert

resource "azapi_resource" "site_webapp_restart_alert" {
  for_each  = local.webapps
  type      = "Microsoft.Insights/activityLogAlerts@2017-04-01"
  name      = "${var.name_prefix}-${each.key}-restart-events-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      enabled = true

      # Search the activity log within this RG (you could also use the subscription scope)
      scopes = [azapi_resource.site-group.id]

      # Fire on successful restarts of this specific web app
      condition = {
        allOf = [
          {
            field  = "category"
            equals = "Administrative"
          },
          {
            field  = "operationName"
            equals = "Microsoft.Web/sites/restart/action"
          },
          {
            field  = "resourceId"
            equals = each.value
          },
          {
            field  = "status"
            equals = "Succeeded"
          }
        ]
      }

      actions = {
        actionGroups = [
          {
            actionGroupId     = azapi_resource.site-action-group.id
            webhookProperties = {} # <-- fixed key
          }
        ]
      }

      description = "Alert when ${each.key} is restarted (Activity Log)"
    }
  }

  tags = merge(local.merged_tags, { purpose = "restart-monitoring" })
}

# =============================================================================
# FRONT DOOR MONITORING ALERTS
# =============================================================================

# Front Door Monitoring - Backend Health Probe Failures
resource "azapi_resource" "site-frontdoor-health-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-frontdoor-health-probe-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description          = "Alert when Front Door origin health falls below 100%"
      severity             = 1
      enabled              = true
      scopes               = [azapi_resource.frontdoor_profile.id]
      evaluationFrequency  = "PT1M"
      windowSize           = "PT5M"
      targetResourceType   = "Microsoft.Cdn/profiles"
      targetResourceRegion = "global"
      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "Origin Health < 100%"
            metricNamespace = "Microsoft.Cdn/profiles"
            metricName      = "OriginHealthPercentage"
            operator        = "LessThan"
            threshold       = 100
            timeAggregation = "Average"
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }
      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "frontdoor-health-monitoring" })
}

# Front Door Monitoring - Latency Spikes Across Regions
resource "azapi_resource" "site-frontdoor-latency-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-frontdoor-latency-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description          = "Alert when Front Door latency exceeds threshold across regions"
      severity             = 2
      enabled              = true
      scopes               = [azapi_resource.frontdoor_profile.id]
      evaluationFrequency  = "PT5M"
      windowSize           = "PT15M"
      targetResourceType   = "Microsoft.Cdn/profiles"
      targetResourceRegion = "global"
      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "Latency > 500ms"
            metricName      = "TotalLatency"
            operator        = "GreaterThan"
            threshold       = 500
            timeAggregation = "Average"
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }
      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "frontdoor-latency-monitoring" })
}

# Front Door Monitoring - Cache Hit Ratio Below Threshold
resource "azapi_resource" "site-frontdoor-cache-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-frontdoor-cache-hit-ratio-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description         = "Alert when Front Door byte cache hit ratio falls below 80%"
      severity            = 2
      enabled             = true
      scopes              = [azapi_resource.frontdoor_profile.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"

      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "Byte Hit Ratio < 80%"
            metricNamespace = "Microsoft.Cdn/profiles"
            metricName      = "ByteHitRatio" # correct metric name
            timeAggregation = "Average"
            operator        = "LessThan"
            threshold       = 80
            criterionType   = "StaticThresholdCriterion"
            dimensions = [
              {
                name     = "Endpoint" # valid dimension for this metric
                operator = "Include"
                values   = ["*"]
              }
            ]
          }
        ]
      }

      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "frontdoor-cache-monitoring" })
}


# =============================================================================
# OUTPUTS
# =============================================================================

## Application Insights instrumentation key output intentionally omitted; requires data-plane access not provided via azapi body here.

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azapi_resource.site-loganalytics-workspace.id
}

output "action_group_id" {
  description = "Action Group ID for alerts"
  value       = azapi_resource.site-action-group.id
}

output "monitoring_resources" {
  description = "Summary of monitoring resources created"
  value = {
    application_insights    = azapi_resource.site-appinsights.name
    log_analytics_workspace = azapi_resource.site-loganalytics-workspace.name
    action_group            = azapi_resource.site-action-group.name
    web_app_alerts = [
      "Memory Usage > ${var.webapp_memory_threshold_mb} MB",
      "HTTP 5xx Errors > 0",
      "Response Time > ${var.webapp_response_time_threshold_ms} ms",
      "Restart Events"
    ]
    front_door_alerts = [
      "Backend Health Probe Failures",
      "Latency Spikes",
      "Cache Hit Ratio < 80%"
    ]
    mysql_alerts = [
      "CPU Utilization > 85%",
      "Storage Usage > 80%",
      "High Connection Count",
      "Deadlocks > 0",
      "Failed Login Attempts > 0",
      "Long-running Queries > 0"
    ]
    redis_alerts = [
      "Memory Usage > 80%",
      "High CPU Usage > 80%",
      "Connection Spikes/Drops"
    ]
    storage_account_alerts = [
      "Transaction Failures > 0",
      "Capacity Usage > threshold",
      "High Latency > 500ms",
      "Availability Interruptions"
    ]
  }
}


# =============================================================================
# AZURE SQL SERVER MONITORING ALERTS
# =============================================================================

# SQL Server - CPU Utilization Alert (>85%)
resource "azapi_resource" "site-sql-cpu-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-mysql-cpu-85-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description         = "Alert when SQL Server CPU utilization exceeds 85%"
      severity            = 2
      enabled             = true
      scopes              = [azapi_resource.mysql_flexible_server.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"
      # targetResourceType/Region omitted (single-resource scope). Region inferred; avoids mismatch.
      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "CPU Utilization > 85%"
            metricName      = "cpu_percent"
            operator        = "GreaterThan"
            threshold       = 85
            timeAggregation = "Average"
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }
      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "mysql-cpu-monitoring" })
}

# SQL Server - Storage Usage Alert (>80%)
resource "azapi_resource" "site-sql-storage-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-mysql-storage-80-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description         = "Alert when SQL Server storage usage exceeds 80%"
      severity            = 2
      enabled             = true
      scopes              = [azapi_resource.mysql_flexible_server.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"
      # targetResourceType/Region omitted (single-resource scope)
      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "Storage Usage > 80%"
            metricName      = "storage_percent"
            operator        = "GreaterThan"
            threshold       = 80
            timeAggregation = "Average"
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }
      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "mysql-storage-monitoring" })
}

# SQL Server - High Database Connection Usage Alert
resource "azapi_resource" "site-sql-connections-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-mysql-connections-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description         = "Alert when SQL Server connection count is high"
      severity            = 2
      enabled             = true
      scopes              = [azapi_resource.mysql_flexible_server.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"
      # targetResourceType/Region omitted (single-resource scope)
      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "High Connection Count"
            metricName      = "active_connections"
            operator        = "GreaterThan"
            threshold       = 80
            timeAggregation = "Average"
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }
      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "mysql-connections-monitoring" })
}

# SQL Server - Log Analytics Query Alert - Database Deadlocks
resource "azapi_resource" "site-sql-deadlocks-alert" {
  type      = "Microsoft.Insights/scheduledQueryRules@2023-12-01"
  name      = "${var.name_prefix}-mysql-deadlocks-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = azapi_resource.site-groupmon.location

  body = {
    properties = {
      description         = "Alert for SQL Server database deadlocks"
      severity            = 1
      enabled             = true
      scopes              = [azapi_resource.site-loganalytics-workspace.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT10M"
      criteria = {
        allOf = [
          {
            query           = "AzureDiagnostics | where ResourceType == 'MYSQLFLEXIBLESERVERS' | where Category == 'MySqlAuditLogs' | where Message contains 'deadlock' | summarize count() by bin(TimeGenerated, 5m)"
            timeAggregation = "Count"
            operator        = "GreaterThan"
            threshold       = 0
            failingPeriods = {
              minFailingPeriodsToAlert  = 1
              numberOfEvaluationPeriods = 1
            }
          }
        ]
      }
      actions = {
        actionGroups = [
          azapi_resource.site-action-group.id
        ]
      }
    }
  }

  tags = merge(local.merged_tags, { purpose = "mysql-deadlocks-monitoring" })
}

# SQL Server - Log Analytics Query Alert - Failed Login Attempts
resource "azapi_resource" "site-sql-failed-logins-alert" {
  type      = "Microsoft.Insights/scheduledQueryRules@2023-12-01"
  name      = "${var.name_prefix}-mysql-failed-logins-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = azapi_resource.site-groupmon.location

  body = {
    properties = {
      description         = "Alert for SQL Server failed login attempts"
      severity            = 1
      enabled             = true
      scopes              = [azapi_resource.site-loganalytics-workspace.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT10M"
      criteria = {
        allOf = [
          {
            query           = "AzureDiagnostics | where ResourceType == 'MYSQLFLEXIBLESERVERS' | where Category == 'MySqlAuditLogs' | where Message contains 'Access denied' or Message contains 'failed' | summarize count() by bin(TimeGenerated, 5m)"
            timeAggregation = "Count"
            operator        = "GreaterThan"
            threshold       = 0
            failingPeriods = {
              minFailingPeriodsToAlert  = 1
              numberOfEvaluationPeriods = 1
            }
          }
        ]
      }
      actions = {
        actionGroups = [
          azapi_resource.site-action-group.id
        ]
      }
    }
  }

  tags = merge(local.merged_tags, { purpose = "mysql-failed-logins-monitoring" })
}

# SQL Server - Log Analytics Query Alert - Long-running Queries
resource "azapi_resource" "site-sql-long-queries-alert" {
  type      = "Microsoft.Insights/scheduledQueryRules@2023-12-01"
  name      = "${var.name_prefix}-mysql-long-queries-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = azapi_resource.site-groupmon.location

  body = {
    properties = {
      description = "Alert for SQL Server long-running queries (>30 seconds)"
      severity    = 2
      enabled     = true
      scopes = [
        azapi_resource.site-loganalytics-workspace.id
      ]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"
      criteria = {
        allOf = [
          {
            query           = <<-KQL
              let longQuerySeconds = 30.0;
              union isfuzzy=true
                (
                  MySqlSlowLogs
                  | extend duration_s = todouble(column_ifexists("Duration_s", real(null)))
                  | where isnotnull(duration_s) and duration_s >= longQuerySeconds
                  | project TimeGenerated
                ),
                (
                  AzureDiagnostics
                  | where Category == "MySqlSlowLogs"
                        and (ResourceType == "MYSQLFLEXIBLESERVERS" or ResourceProvider == "MICROSOFT.DBFORMYSQL")
                  // Parse "Query_time: X.XXX" from the slow log message
                  | extend duration_s = todouble(extract(@"Query_time:?\\s*([0-9\\.]+)", 1, tostring(Message)))
                  | where isnotnull(duration_s) and duration_s >= longQuerySeconds
                  | project TimeGenerated
                )
              | summarize Count = count() by bin(TimeGenerated, 5m)
            KQL
            timeAggregation = "Count"
            operator        = "GreaterThan"
            threshold       = 0
            failingPeriods = {
              minFailingPeriodsToAlert  = 1
              numberOfEvaluationPeriods = 1
            }
          }
        ]
      }
      actions = {
        actionGroups = [
          azapi_resource.site-action-group.id
        ]
      }
    }
  }

  tags = merge(local.merged_tags, { purpose = "mysql-long-queries-monitoring" })
}

# =============================================================================
# MySQL Flexible Server - Restart Events (Activity Log)
resource "azapi_resource" "site-mysql-restart-alert" {
  type      = "Microsoft.Insights/activityLogAlerts@2017-04-01"
  name      = "${var.name_prefix}-mysql-restart-events-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      enabled = true
      scopes  = [azapi_resource.site-group.id]
      condition = {
        allOf = [
          { field = "category", equals = "Administrative" },
          { field = "operationName", equals = "Microsoft.DBforMySQL/flexibleServers/restart/action" },
          { field = "resourceId", equals = azapi_resource.mysql_flexible_server.id },
          { field = "status", equals = "Succeeded" }
        ]
      }
      actions = {
        actionGroups = [
          { actionGroupId = azapi_resource.site-action-group.id }
        ]
      }
      description = "Alert when MySQL Flexible Server is restarted (Activity Log)"
    }
  }

  tags = merge(local.merged_tags, { purpose = "mysql-restart-monitoring" })
}

# =============================================================================
# REDIS CACHE MONITORING ALERTS
# =============================================================================

# Redis Cache - Memory Usage Alert (>80%)
resource "azapi_resource" "site-redis-memory-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-redis-memory-80-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description         = "Alert when Redis Cache memory usage exceeds 80%"
      severity            = 2
      enabled             = true
      scopes              = [azapi_resource.redis_enterprise.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"
      # Single Redis Enterprise resource; omit explicit targetResourceType/Region to avoid region mismatch
      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "Memory Usage > 80%"
            metricNamespace = "Microsoft.Cache/redisEnterprise"
            metricName      = "usedmemorypercentage"
            operator        = "GreaterThan"
            threshold       = 80
            timeAggregation = "Average"
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }
      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "redis-memory-monitoring" })
}


# Redis Cache - Sustained High CPU Usage Alert
resource "azapi_resource" "site-redis-cpu-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-redis-cpu-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description         = "Alert when Redis Cache CPU usage is sustained high"
      severity            = 2
      enabled             = true
      scopes              = [azapi_resource.redis_enterprise.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"
      # Single Redis Enterprise resource; omit explicit targetResourceType/Region
      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "High Server Load > 80%"
            metricNamespace = "Microsoft.Cache/redisEnterprise"
            metricName      = "serverload"
            operator        = "GreaterThan"
            threshold       = 80
            timeAggregation = "Average"
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }
      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "redis-cpu-monitoring" })
}

# Redis Cache - Log Analytics Query Alert - Connection Spikes/Drops
resource "azapi_resource" "site-redis-connections-alert" {
  type      = "Microsoft.Insights/scheduledQueryRules@2023-12-01"
  name      = "${var.name_prefix}-redis-connections-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = azapi_resource.site-groupmon.location

  body = {
    properties = {
      description         = "Alert for Redis Cache connection spikes or drops"
      severity            = 2
      enabled             = true
      scopes              = [azapi_resource.site-loganalytics-workspace.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"
      criteria = {
        allOf = [
          {
            query           = "AzureDiagnostics | where ResourceType == 'REDIS' | where Category == 'RedisLogs' | where Message contains 'connection' | summarize count() by bin(TimeGenerated, 5m) | where count_ < 5 or count_ > 100"
            timeAggregation = "Count"
            operator        = "GreaterThan"
            threshold       = 0
            failingPeriods = {
              minFailingPeriodsToAlert  = 1
              numberOfEvaluationPeriods = 1
            }
          }
        ]
      }
      actions = {
        actionGroups = [
          azapi_resource.site-action-group.id
        ]
      }
    }
  }

  tags = merge(local.merged_tags, { purpose = "redis-connections-monitoring" })
}

# =============================================================================
# STORAGE ACCOUNT MONITORING ALERTS
# =============================================================================

############################
# Storage - Transaction Failures (metric alert)
############################
resource "azapi_resource" "site-storage-transaction-failures-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-storage-transaction-failures-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description = "Alert when Storage Account transaction failures occur"
      severity    = 1
      enabled     = true
      scopes      = [azapi_resource.site-storage.id]

      evaluationFrequency = "PT1M"
      windowSize          = "PT5M"

      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "Transaction Failures > 0"
            metricNamespace = "Microsoft.Storage/storageAccounts"
            metricName      = "Transactions"
            timeAggregation = "Total"
            operator        = "GreaterThan"
            threshold       = 0
            criterionType   = "StaticThresholdCriterion"
            dimensions = [
              {
                name     = "ResponseType"
                operator = "Include"
                values   = ["ServerOtherError", "ClientOtherError", "ClientThrottlingError", "AuthorizationError", "SASAuthorizationError", "ThrottleError", "ServerTimeoutError"]
              }
            ]
          }
        ]
      }

      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {} # <- Capital H
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "storage-transaction-monitoring" })
}

# Storage - Capacity (metric alert) — fixed windows for UsedCapacity
## storage_used_capacity_threshold_bytes variable centralized in variables.tf

resource "azapi_resource" "site-storage-capacity-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-storage-capacity-80-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description = "Alert when Storage Account UsedCapacity exceeds threshold (bytes)"
      severity    = 2
      enabled     = true
      scopes      = [azapi_resource.site-storage.id]

      evaluationFrequency = "PT15M" # <= windowSize
      windowSize          = "PT1H"  # UsedCapacity requires PT1H | PT6H | PT12H | P1D

      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "UsedCapacity over threshold"
            metricNamespace = "Microsoft.Storage/storageAccounts"
            metricName      = "UsedCapacity" # bytes
            timeAggregation = "Average"
            operator        = "GreaterThan"
            threshold       = var.storage_used_capacity_threshold_bytes
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }

      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {}
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "storage-capacity-monitoring" })
}

resource "azapi_resource" "site-storage-latency-alert" {
  type      = "Microsoft.Insights/metricAlerts@2018-03-01"
  name      = "${var.name_prefix}-storage-latency-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = "global"

  body = {
    properties = {
      description = "Alert when Storage Account latency exceeds threshold"
      severity    = 2
      enabled     = true
      scopes      = [azapi_resource.site-storage.id]

      evaluationFrequency = "PT5M"
      windowSize          = "PT15M" # PT10M invalid

      criteria = {
        "odata.type" = "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria"
        allOf = [
          {
            name            = "High Latency > 500ms"
            metricNamespace = "Microsoft.Storage/storageAccounts"
            metricName      = "SuccessE2ELatency" # ms
            timeAggregation = "Average"
            operator        = "GreaterThan"
            threshold       = 500
            criterionType   = "StaticThresholdCriterion"
            dimensions      = []
          }
        ]
      }

      actions = [
        {
          actionGroupId     = azapi_resource.site-action-group.id
          webHookProperties = {} # <- Capital H
        }
      ]
    }
  }

  tags = merge(local.merged_tags, { purpose = "storage-latency-monitoring" })
}

resource "azapi_resource" "site-storage-availability-alert" {
  type      = "Microsoft.Insights/scheduledQueryRules@2023-12-01"
  name      = "${var.name_prefix}-storage-availability-${var.environment}"
  parent_id = azapi_resource.site-groupmon.id
  location  = azapi_resource.site-groupmon.location

  body = {
    properties = {
      description         = "Alert for Storage Account availability interruptions (HTTP 5xx)"
      severity            = 1
      enabled             = true
      scopes              = [azapi_resource.site-loganalytics-workspace.id]
      evaluationFrequency = "PT5M"
      windowSize          = "PT15M"

      criteria = {
        allOf = [
          {
            // Works with both legacy AzureDiagnostics and newer schemas
            query           = <<-KQL
              AzureDiagnostics
              | where ResourceProvider == 'MICROSOFT.STORAGE'
              | where Category in ('StorageRead','StorageWrite','StorageDelete')
              // Normalize status code from whatever column exists
              | extend httpStatus =
                  toint(
                    column_ifexists("StatusCode",
                    column_ifexists("StatusCode_d",
                    column_ifexists("HttpStatusCode_d",
                    column_ifexists("HttpStatusCode",
                    column_ifexists("HttpStatusCode_s", real(null))))))
                  )
              | where httpStatus in (500, 503)
            KQL
            timeAggregation = "Count"
            operator        = "GreaterThan"
            threshold       = 0
            failingPeriods = {
              numberOfEvaluationPeriods = 1
              minFailingPeriodsToAlert  = 1
            }
            dimensions = []
          }
        ]
      }

      actions = {
        actionGroups = [azapi_resource.site-action-group.id]
      }
    }
  }

  tags = merge(local.merged_tags, { purpose = "storage-availability-monitoring" })
}
