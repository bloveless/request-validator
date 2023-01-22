package request_validator

import (
	"fmt"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
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
