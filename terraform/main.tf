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