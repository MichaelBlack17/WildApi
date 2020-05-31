package main

import (
	"Models"
	"database/sql"
	"encoding/json"
	"fmt"
	_ "github.com/lib/pq"
	"net/http"
	"os"
	"strconv"
	. "time"
)

type Configuration struct {
	ServerPort       string
	ConnectionString string
	SqlDriverName    string
}

type Repository struct{
	Context *sql.DB
	config *Configuration
}

func (repo *Repository) InitConfig() {

	file, _ := os.Open(`D:\learn go\WildApi\src\config.json`)
	defer file.Close()
	decoder := json.NewDecoder(file)
	configuration := Configuration{}
	err := decoder.Decode(&configuration)
	if err != nil {
		fmt.Println("error:", err)
	}
	repo.config = &configuration
}

func (repo *Repository) StartQueryManagement(){
	for{
		Sleep(15 * Minute)
		repo.Context.QueryRow("SELECT querymanagement()")
	}

}

func (repo *Repository) CreateLogRecord(LogMessage string) int64 {
	res := repo.Context.QueryRow("SELECT addlogrecord($1)", LogMessage)
	var t int64
	res.Scan(&t)
	return t
}

//Вызов хранимой процедуры AddRequest в базе данных
func (repo *Repository) AddRequest(text string) int64 {
	res := repo.Context.QueryRow("SELECT addrequest($1)", text)
	var t int64
	res.Scan(&t)
	return t
}

//Вызов хранимой процедуры RemoveRequest в базе данных
func (repo *Repository) RemoveRequest(ReqId int64) int64 {
	res := repo.Context.QueryRow("SELECT removerequest($1)", ReqId)
	var t int64
	res.Scan(&t)
	return t
}

func (repo *Repository) Connect() error {
	connStr := repo.config.ConnectionString
	db, err := sql.Open(repo.config.SqlDriverName, connStr)
	if err != nil {
		println("no db connection")
		panic(err)
	}
	repo.Context = db
	return err
}

func (repo *Repository) Disconnect() {
	repo.Context.Close()
}

func (repo *Repository) APIAddRequest(w http.ResponseWriter, r *http.Request){
	var req Models.AddRequestRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	rez := repo.AddRequest(req.Message)

	resp := Models.AddRequestResponse{
		 ReqId: rez,
	}

	LogMessage := `request added. Id: ` + strconv.FormatInt(rez, 10)
	repo.CreateLogRecord(LogMessage)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (repo *Repository) APIRemoveRequest(w http.ResponseWriter, r *http.Request){
	var req Models.RemoveRequestRequest

	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	msg := ""
	rez := repo.RemoveRequest(req.ReqId)
	if rez == 0{
		msg = "Request " + strconv.FormatInt(req.ReqId, 10) + " successfully canceled"
	}
	if rez == 1{
		msg = "Request " + strconv.FormatInt(req.ReqId, 10) + " in processing or missing"
	}

	resp := Models.RemoveRequestResponse{
		Message: msg,
	}

	LogMessage := "Request cacel try: " + msg
	repo.CreateLogRecord(LogMessage)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (repo *Repository) APICheck(w http.ResponseWriter, r *http.Request){
	fmt.Fprintln(w, "Wild API")
}

func runServer(repo *Repository) {
	mux := http.NewServeMux()
	mux.HandleFunc("/AddRequest", repo.APIAddRequest)
	mux.HandleFunc("/RemoveRequest", repo.APIRemoveRequest)
	mux.HandleFunc("/", repo.APICheck)

	server := &http.Server{
		Addr:              repo.config.ServerPort,
		Handler:           mux,
	}

	fmt.Println("Server started at ",repo.config.ServerPort)
	server.ListenAndServe()
}

func main() {

	//подключение api к бд
	repo := &Repository{nil, nil}
	repo.InitConfig()
	repo.Connect()

	defer repo.Disconnect()

	runServer(repo)

}

