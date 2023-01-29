.PHONY: up local-api

up:
	docker compose up -d
	go run cmd/http/main.go

generate:
	sqlc -x generate

local-api:
	sam build
	sam local start-api

install-sqlc:
	go install github.com/kyleconroy/sqlc/cmd/sqlc@main