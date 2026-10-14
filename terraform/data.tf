resource "random_password" "database_master" {
  length           = 40
  special          = false
  override_special = ""
}

resource "random_password" "database_app" {
  length           = 48
  special          = false
  override_special = ""
}

resource "random_id" "snapshot" {
  byte_length = 4
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]
}

resource "aws_db_parameter_group" "main" {
  name   = "${local.name}-postgres16"
  family = "postgres16"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "main" {
  identifier                 = local.name
  engine                     = "postgres"
  engine_version             = var.postgres_engine_version
  instance_class             = var.postgres_instance_class
  allocated_storage          = var.postgres_storage_gib
  max_allocated_storage      = var.postgres_max_storage_gib
  storage_type               = "gp3"
  storage_encrypted          = true
  db_name                    = "journal"
  username                   = "journal_admin"
  password                   = random_password.database_master.result
  port                       = 5432
  db_subnet_group_name       = aws_db_subnet_group.main.name
  parameter_group_name       = aws_db_parameter_group.main.name
  vpc_security_group_ids     = [aws_security_group.database.id]
  publicly_accessible        = false
  multi_az                   = var.postgres_multi_az
  backup_retention_period    = 7
  auto_minor_version_upgrade = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${local.name}-final-${random_id.snapshot.hex}"
  apply_immediately          = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "database_admin" {
  name                    = "${local.name}/database/admin"
  description             = "RDS administrator bootstrap credentials for ${local.name}."
  recovery_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "database_admin" {
  secret_id = aws_secretsmanager_secret.database_admin.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.database_master.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    database = aws_db_instance.main.db_name
  })
}

resource "aws_secretsmanager_secret" "database_app" {
  name                    = "${local.name}/database/app"
  description             = "Least-privilege Journal API PostgreSQL credentials for ${local.name}."
  recovery_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "database_app" {
  secret_id = aws_secretsmanager_secret.database_app.id
  secret_string = jsonencode({
    username = "journal_api_app"
    password = random_password.database_app.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    database = aws_db_instance.main.db_name
  })
}

resource "aws_ecr_repository" "api" {
  name                 = local.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain the 30 most recent images."
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 30
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name}-http-5xx"
  alarm_description   = "Journal API emitted at least one HTTP 5xx response."
  namespace           = "JournalAPI"
  metric_name         = "journal_api_http_5xx_total"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.api_alarm.arn]

  dimensions = {
    "service.name" = "journal-api"
  }
}

resource "aws_sns_topic" "api_alarm" {
  name = "${local.name}-alarms"
}

resource "aws_sns_topic_subscription" "api_alarm_email" {
  topic_arn = aws_sns_topic.api_alarm.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

resource "aws_cloudwatch_dashboard" "api" {
  dashboard_name = "${local.name}-operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Journal API request rate"
          view   = "timeSeries"
          region = var.aws_region
          period = 60
          metrics = [
            ["JournalAPI", "journal_api_http_requests_total", "service.name", "journal-api", { stat = "Sum", label = "Requests" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Journal API request latency"
          view   = "timeSeries"
          region = var.aws_region
          period = 60
          metrics = [
            ["JournalAPI", "journal_api_http_request_duration_seconds", "service.name", "journal-api", { stat = "p95", label = "p95 seconds" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Journal API 5xx errors"
          view   = "timeSeries"
          region = var.aws_region
          period = 60
          metrics = [
            ["JournalAPI", "journal_api_http_5xx_total", "service.name", "journal-api", { stat = "Sum", label = "5xx errors" }]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "otel_metrics" {
  name              = "/aws/metrics/journal-api"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/containerinsights/${local.name}/application"
  retention_in_days = 30
}
