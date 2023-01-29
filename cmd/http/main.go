package main

import (
	"context"
	"github.com/jackc/pgx/v5/pgxpool"
	"log"
	"net/http"
	"request_validator"
	"request_validator/models"
)

func main() {
	db, err := pgxpool.New(context.Background(), "postgres://postgres:postgres@localhost:5432/postgres")
	if err != nil {
		panic(err)
	}

	models.New(db)

	r := request_validator.NewRouter()

	log.Println("Listening on :3000")
	err = http.ListenAndServe(":3000", r)
	if err != nil {
		log.Fatalln("Unable to start server on :3000")
	}
}
