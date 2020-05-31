package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net/http"
)

func AddRequest()[]byte{
	url := "http://localhost:8080/AddRequest"
	fmt.Println("URL:>", url)

	var jsonStr = []byte(`{"Message":"Test api 1"}`)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonStr))
	req.Header.Set("X-Custom-Header", "myvalue")
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	fmt.Println("response Status:", resp.Status)
	fmt.Println("response Headers:", resp.Header)
	body, _ := ioutil.ReadAll(resp.Body)
	fmt.Println("response Body:", string(body))
	return body
}

func RemoveRequest(reqbody []byte ){
	url := "http://localhost:8080/RemoveRequest"
	fmt.Println("URL:>", url)

	var jsonStr = reqbody
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonStr))
	req.Header.Set("X-Custom-Header", "myvalue")
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	fmt.Println("response Status:", resp.Status)
	fmt.Println("response Headers:", resp.Header)
	body, _ := ioutil.ReadAll(resp.Body)
	fmt.Println("response Body:", string(body))

}

func main() {
	//body :=
		AddRequest()
	//RemoveRequest(body)

}

