package request_validator

import (
	"fmt"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/gookit/validate"
)

type request struct {
	String string `json:"string"`
	Bool   bool   `json:"bool"`
	Number int64  `json:"number"`
}

func NewRouter() *chi.Mux {
	router := chi.NewRouter()

	// A good base middleware stack
	router.Use(middleware.RequestID)
	router.Use(middleware.RealIP)
	router.Use(middleware.Logger)
	router.Use(middleware.Recoverer)

	// CORS is ignored by API Gateway but this probably needs to be here for local development
	router.Use(cors.Handler(cors.Options{
		AllowOriginFunc:  AllowOriginFunc,
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300, // Maximum value not ignored by any of major browsers
	}))

	router.Get("/", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("Hello"))
	})

	router.Post("/", func(w http.ResponseWriter, r *http.Request) {
		data, err := validate.FromRequest(r)
		if err != nil {
			panic(err)
		}

		v := data.Create()
		v.StringRules(validate.MS{
			"string": "required",
			"bool":   "required",
			"number": "required|gt:0",
		})

		log.Printf("validate: %+v", v.Validate())

		if v.Validate() {
			r := &request{}
			err = v.BindSafeData(r)
			if err != nil {
				panic(err)
			}

			log.Printf("data: %+v", v.SafeData())
			log.Printf("request: %+v", r)

			_, _ = w.Write([]byte(fmt.Sprintf("request is valid: %+v", r)))
		} else {
			log.Println(v.Errors) // all error messages

			_, _ = w.Write([]byte(fmt.Sprintf("request is invalid: %v", v.Errors)))
		}
	})

	return router
}

func AllowOriginFunc(r *http.Request, origin string) bool {
	return true
}
