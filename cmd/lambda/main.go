package main

import (
	"request_validator"

	"github.com/aws/aws-lambda-go/lambda"
	chiadapter "github.com/awslabs/aws-lambda-go-api-proxy/chi"
)

func main() {
	r := request_validator.NewRouter()
	lambda.Start(chiadapter.New(r).ProxyWithContext)
}
