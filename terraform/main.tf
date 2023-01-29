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

resource "aws_acm_certificate" "api_brennonloveless_com" {
  domain_name       = "api.brennonloveless.com"
  validation_method = "DNS"
}

module "zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "api.brennonloveless.com" = {
      comment = "api.brennonloveless.com (production)"
      tags    = {
        env = "production"
      }
    }
  }

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_route53_record" "api_brennonloveless_com" {
  for_each = {
    for dvo in aws_acm_certificate.api_brennonloveless_com.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = module.zones.route53_zone_zone_id["api.brennonloveless.com"]
}

resource "aws_acm_certificate_validation" "api_brennonloveless_com" {
  certificate_arn         = aws_acm_certificate.api_brennonloveless_com.arn
  validation_record_fqdns = [for record in aws_route53_record.api_brennonloveless_com : record.fqdn]
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

  # Custom domain
  domain_name                 = "api.brennonloveless.com"
  domain_name_certificate_arn = aws_acm_certificate.api_brennonloveless_com.arn

  # Access logs
  default_stage_access_log_destination_arn = aws_cloudwatch_log_group.request_validator.arn
  default_stage_access_log_format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"

  # Routes and integrations
  integrations = {
    "GET /" = {
      lambda_arn             = module.lambda_function.lambda_function_arn
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
      authorization_type         = "AWS_IAM"
    }

    "POST /" = {
      lambda_arn             = module.lambda_function.lambda_function_arn
      payload_format_version = "1.0" // posts seem to require payload format version 1.0
      timeout_milliseconds   = 12000
      authorization_type         = "AWS_IAM"
    }

    "$default" = {
      lambda_arn = module.lambda_function.lambda_function_arn
    }
  }
}

resource "aws_iam_role" "unauthenticated" {
  name = "cognito-unauthenticated"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "cognito-identity.amazonaws.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.api_brennonloveless_com.id}"
                },
                "ForAnyValue:StringLike": {
                    "cognito-identity.amazonaws.com:amr": "unauthenticated"
                }
            }
        }
    ]
}
EOF
}


resource "aws_iam_role_policy" "unauthenticated" {
  name = "unauthenticated-policy"
  role = aws_iam_role.unauthenticated.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "mobileanalytics:PutEvents",
        "cognito-sync:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "authenticated" {
  name = "cognito-authenticated"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "cognito-identity.amazonaws.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.api_brennonloveless_com.id}"
                },
                "ForAnyValue:StringLike": {
                    "cognito-identity.amazonaws.com:amr": "authenticated"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "authenticated" {
  name = "authenticated-policy"
  role = aws_iam_role.authenticated.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "mobileanalytics:PutEvents",
        "cognito-sync:*",
        "cognito-identity:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "admin_authenticated" {
  name = "cognito-admin-authenticated"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "cognito-identity.amazonaws.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.api_brennonloveless_com.id}"
                },
                "ForAnyValue:StringLike": {
                    "cognito-identity.amazonaws.com:amr": "authenticated"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "admin_authenticated" {
  name = "admin-authenticated-policy"
  role = aws_iam_role.admin_authenticated.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "mobileanalytics:PutEvents",
        "cognito-sync:*",
        "cognito-identity:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_openid_connect_provider" "auth0" {
  url = "https://dev-kjqsk80b2mpf2n3b.us.auth0.com"

  client_id_list = [
    "rMvyjAAStpUetQcYpw96wGV9PfYaTuay",
  ]

  thumbprint_list = ["933C6DDEE95C9C41A40F9F50493D82BE03AD87BF"]
}

resource "aws_cognito_identity_pool" "api_brennonloveless_com" {
  identity_pool_name               = "api-brennonloveless-com"
  allow_unauthenticated_identities = true
  allow_classic_flow               = false

  openid_connect_provider_arns = [
    aws_iam_openid_connect_provider.auth0.arn
  ]
}

resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.api_brennonloveless_com.id

  role_mapping {
    identity_provider         = aws_iam_openid_connect_provider.auth0.arn
    ambiguous_role_resolution = "AuthenticatedRole"
    type                      = "Rules"

    mapping_rule {
      claim      = "https://api.brennonloveless.com/roles"
      match_type = "Contains"
      role_arn   = aws_iam_role.admin_authenticated.arn
      value      = "Admin"
    }
  }

  roles = {
    "authenticated" = aws_iam_role.authenticated.arn,
    "unauthenticated" = aws_iam_role.unauthenticated.arn,
  }
}
