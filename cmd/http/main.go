package main

import (
	"log"
	"net/http"
	"request_validator"
)

func main() {
	r := request_validator.NewRouter()

	log.Println("Listening on :3000")
	err := http.ListenAndServe(":3000", r)
	if err != nil {
		log.Fatalln("Unable to start server on :3000")
	}
}
