terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  #  backend "s3" {
  #    bucket = "terraform-state"
  #    key    = "request-validator"
  #    region = "us-west-2"
  #    dynamodb_table = "terraform-locks"
  #  }
}

provider "aws" {
  region  = "us-west-2"
  profile = "personal"
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "request-validator"
  handler       = "main"
  runtime       = "go1.x"
  publish       = true

  source_path = [
    {
      path     = "${path.module}/../cmd/lambda",
      patterns = ["main"]
      commands = [
        "GOOS=linux GOARCH=amd64 go build -o main",
        ":zip"
      ]
    }
  ]

  store_on_s3 = false

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*"
    }
  }

  environment_variables = {
    Serverless = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "request_validator" {
  name = "request_validator_api_access_logs"
}

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name          = "request-validator"
  description   = "My awesome HTTP API Gateway"
  protocol_type = "HTTP"

  cors_configuration = {
    allow_headers = [
      "content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"
    ]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  create_api_domain_name = false

  # Custom domain
  #  domain_name                 = "terraform-aws-modules.modules.tf"
  #  domain_name_certificate_arn = "arn:aws:acm:eu-west-1:052235179155:certificate/2b3a7ed9-05e1-4f9e-952b-27744ba06da6"

  # Access logs
  default_stage_access_log_destination_arn = aws_cloudwatch_log_group.request_validator.arn
  default_stage_access_log_format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"

  # Routes and integrations
  integrations = {
    "GET /" = {
      lambda_arn             = module.lambda_function.lambda_function_arn
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
    }

    "POST /" = {
      lambda_arn             = module.lambda_function.lambda_function_arn
      payload_format_version = "1.0" // posts seem to require payload format version 1.0
      timeout_milliseconds   = 12000
    }

    "$default" = {
      lambda_arn = module.lambda_function.lambda_function_arn
    }
  }
}