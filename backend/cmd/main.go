package main

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
)

type transactionRequest struct {
	Amount      float64 `json:"amount"`
	Description string  `json:"description"`
}

type transactionResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/transactions", handleTransactions)

	log.Println("Servidor EcoWallet iniciado em http://localhost:8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatalf("falha ao iniciar servidor HTTP: %v", err)
	}
}

func handleTransactions(w http.ResponseWriter, r *http.Request) {
	log.Printf("Rota /api/transactions acessada: %s %s", r.Method, r.URL.Path)

	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		http.Error(w, "método não permitido", http.StatusMethodNotAllowed)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var transaction transactionRequest
	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(&transaction); err != nil {
		http.Error(w, "JSON inválido", http.StatusBadRequest)
		return
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		http.Error(w, "envie apenas um objeto JSON", http.StatusBadRequest)
		return
	}
	if transaction.Amount <= 0 || transaction.Description == "" {
		http.Error(w, "amount deve ser positivo e description não pode ser vazia", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(transactionResponse{
		Success: true,
		Message: "Transação recebida com sucesso",
	}); err != nil {
		log.Printf("Falha ao escrever resposta: %v", err)
	}
}
