output "lambda_name" {
  value = aws_lambda_function.api.function_name
}

output "api_gateway_url" {
  value = aws_apigatewayv2_stage.prod.invoke_url
}