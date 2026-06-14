####################################
# IAM ROLE
####################################

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Action = "sts:AssumeRole"

        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

####################################
# CLOUDWATCH LOGS
####################################

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = 7
}

####################################
# LAMBDA
####################################

resource "aws_lambda_function" "api" {

  function_name = "${var.project_name}-lambda"

  filename = "lambda.zip"

  source_code_hash = filebase64sha256("lambda.zip")

  role = aws_iam_role.lambda_role.arn

  handler = "bootstrap"

  runtime = "provided.al2"

  timeout = 30

  memory_size = 256

  environment {
    variables = {
      DATABASE_URL = "postgresql://postgres.rvftlzsadhwsmuoeogqv:tUnRonXIeR0brszf@aws-1-us-east-2.pooler.supabase.com:5432/postgres?sslmode=require"
      JWT_SECRET = "MiSuperSecretoJWT"
    }
  }
}

####################################
# API GATEWAY HTTP
####################################

resource "aws_apigatewayv2_api" "api_gateway" {

  name          = "${var.project_name}-gateway"

  protocol_type = "HTTP"

  cors_configuration {
  allow_origins = ["*"]
  allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  allow_headers = ["*"]
}
}

resource "aws_apigatewayv2_integration" "lambda" {

  api_id = aws_apigatewayv2_api.api_gateway.id

  integration_type = "AWS_PROXY"

  integration_uri = aws_lambda_function.api.invoke_arn

  integration_method = "POST"

  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {

  api_id = aws_apigatewayv2_api.api_gateway.id

  route_key = "$default"

  target = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "prod" {

  api_id = aws_apigatewayv2_api.api_gateway.id

  name = "$default"

  auto_deploy = true
}

####################################
# PERMISOS API GATEWAY -> LAMBDA
####################################

resource "aws_lambda_permission" "api_gateway" {

  statement_id = "AllowExecutionFromAPIGateway"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.api.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*/*"
}

####################################
# NOTIFICATION LAMBDA
####################################

resource "aws_lambda_function" "notification_lambda" {

  function_name = "notification-lambda"

  filename = "notification.zip"

  source_code_hash = filebase64sha256("notification.zip")

  role = aws_iam_role.lambda_role.arn

  handler = "bootstrap"

  runtime = "provided.al2"

  timeout = 30

  memory_size = 256
}

####################################
# SQS -> NOTIFICATION LAMBDA
####################################

resource "aws_lambda_event_source_mapping" "notification_trigger" {

  event_source_arn = aws_sqs_queue.notifications.arn

  function_name = aws_lambda_function.notification_lambda.arn

  batch_size = 1
}


####################################
# SNS
####################################

resource "aws_sns_topic" "notifications" {
  name = "user-notifications-topic"
}

####################################
# SQS
####################################

resource "aws_sqs_queue" "notifications" {
  name = "notification-queue"
}

####################################
# SNS -> SQS
####################################

resource "aws_sns_topic_subscription" "sqs_subscription" {
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notifications.arn
}

####################################
# PERMISO SNS -> SQS
####################################

resource "aws_sqs_queue_policy" "allow_sns" {

  queue_url = aws_sqs_queue.notifications.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = "*"

        Action = "sqs:SendMessage"

        Resource = aws_sqs_queue.notifications.arn

        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.notifications.arn
          }
        }
      }
    ]
  })
}