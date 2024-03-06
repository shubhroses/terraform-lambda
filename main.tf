provider "aws" {
  region = "us-east-1"
}

# Retrieve the secret
data "aws_secretsmanager_secret" "kafka_secret" {
  name = "KafkaSecrets"
}

# Retrieve the secret version
data "aws_secretsmanager_secret_version" "kafka_secret_version" {
  secret_id = data.aws_secretsmanager_secret.kafka_secret.id
}

# IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
    }]
  })

  # Inline policy for Event Bridge access
  inline_policy {
    name = "EventBridgeAccess"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = "events:PutEvents",
          Effect = "Allow",
          Resource = "arn:aws:events:us-east-1:151523899965:event-bus/shubhroses_event_bus_terraform"
        }
      ]
    })
  }

  # Add an inline policy for Secrets Manager access
  inline_policy {
    name = "SecretsManagerAccess"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = "secretsmanager:GetSecretValue",
          Effect = "Allow",
          Resource = "arn:aws:secretsmanager:us-east-1:151523899965:secret:KafkaSecrets-LT9YVL"
        }
      ]
    })
  }

  # Inline policy for S3 access
  inline_policy {
    name = "S3Access"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ],
          Effect = "Allow",
          Resource = [
            "arn:aws:s3:::shubhrose-bucket",
            "arn:aws:s3:::shubhrose-bucket/*"
          ]
        }
      ]
    })
  }
}


# Lambda layer
resource "aws_lambda_layer_version" "kafka_layer" {
  filename   = "kafkaLibrary.zip"
  layer_name = "kafka_library"

  compatible_runtimes = ["python3.9"] # Specify compatible runtimes for your layer
}

# Lambda function
resource "aws_lambda_function" "hello_world" {
  filename      = "lambda_function_payload.zip"
  function_name = "shubhrose_function_terraform"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler" # Adjusted for Python convention
  runtime       = "python3.9"                      # Set to Python 3.9
  layers        = [aws_lambda_layer_version.kafka_layer.arn]
  environment {
    variables = {
        KAFKA_SECRET_ARN = data.aws_secretsmanager_secret_version.kafka_secret_version.arn
    }
  }

  source_code_hash = filebase64sha256("lambda_function_payload.zip")
}

# EventBridge bus
resource "aws_cloudwatch_event_bus" "custom_bus" {
  name = "shubhroses_event_bus_terraform"
}

# EventBridge rule
resource "aws_cloudwatch_event_rule" "shubhroses_rule" {
  name        = "shubhroses_rule_terraform"
  event_bus_name = "shubhroses_event_bus_terraform"
  event_pattern  = jsonencode({
    source     = ["CDA"],
    "detail-type" = ["CDA Service Lifecycle Events"]
  })
  depends_on = [aws_cloudwatch_event_bus.custom_bus]
}

# Target for the EventBridge rule
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.shubhroses_rule.name
  target_id = "TargetFunction"
  arn       = aws_lambda_function.hello_world.arn

  # Explicitly specify the event bus if it's not the default one
  event_bus_name = aws_cloudwatch_event_bus.custom_bus.name
}

# Grant the EventBridge rule permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_event_bridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.shubhroses_rule.arn
}

# Lambda function to trigger the EventBridge rule
resource "aws_lambda_function" "event_bridge_trigger" {
  filename         = "event_bridge_trigger_function.zip"
  function_name    = "event_bridge_trigger_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "event_bridge_trigger_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("event_bridge_trigger_function.zip")
}
