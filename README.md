# Request Validator

This example app showcases using `aws-lambda-go-api-proxy` in order reduce code duplication. You'll notice that `cmd/http/main.go` and `cmd/lambda/main.go` are incredibly simple and delegate almost all the code to a standard chi router.

It also uses `gookit/validate` to do request validation. Validation are currently in `router.go` for simplicity.

You can run this application in three ways.

1. `make up` <-- this is an example of running chi directly for local development
2. `make local-api` <-- this is an example of running the the api gateway locally using AWS SAM
3. `cd terraform && terraform apply` <-- this is an example of deploying the api to AWS
