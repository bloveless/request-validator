.PHONY: up local-api

up:
	go run cmd/http/main.go

local-api:
	sam build
	sam local start-api
