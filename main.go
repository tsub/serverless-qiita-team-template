package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/kms"
)

type (
	Client struct {
		Token      string
		Team       string
		TemplateID string
	}

	Template struct {
		ID            int    `json:"id"`
		Name          string `json:"name"`
		Title         string `json:"title"`
		Body          string `json:"body"`
		Tags          []Tag  `json:"tags"`
		ExpandedTitle string `json:"expanded_title"`
		ExpandedBody  string `json:"expanded_body"`
		ExpandedTags  []Tag  `json:"expanded_tags"`
	}

	Tag struct {
		Name     string   `json:"name"`
		Versions []string `json:"versions"`
	}

	CreateItemRequest struct {
		Title     string `json:"title"`
		Body      string `json:"body"`
		Tags      []Tag  `json:"tags"`
		Coediting bool   `json:"coediting"`
	}

	CreateItemResponse struct {
		URL string `json:"url"`
	}
)

func decrypt(str string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(str)
	if err != nil {
		return "", err
	}

	svc := kms.New(session.New())
	input := &kms.DecryptInput{
		CiphertextBlob: data,
	}

	resp, err := svc.Decrypt(input)
	if err != nil {
		return "", err
	}

	return string(resp.Plaintext[:]), nil
}

func (c *Client) GetTemplate() (*Template, error) {
	client := &http.Client{}

	req, err := http.NewRequest("GET", "https://"+c.Team+".qiita.com/api/v2/templates/"+c.TemplateID, nil)
	req.Header.Add("Authorization", "Bearer "+c.Token)
	req.Header.Add("Accept", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()
	template := new(Template)
	err = json.NewDecoder(resp.Body).Decode(&template)
	if err != nil {
		return nil, err
	}

	return template, nil
}

func (c *Client) CreateItem(title string, body string, tags []Tag) (string, error) {
	client := &http.Client{}

	params := &CreateItemRequest{
		Title:     title,
		Body:      body,
		Tags:      tags,
		Coediting: true,
	}
	jsonParams, err := json.Marshal(params)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequest("POST", "https://"+c.Team+".qiita.com/api/v2/items", bytes.NewBuffer(jsonParams))
	req.Header.Add("Authorization", "Bearer "+c.Token)
	req.Header.Add("Accept", "application/json")
	req.Header.Add("Content-Type", "application/json; charset=utf-8")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}

	defer resp.Body.Close()
	response := new(CreateItemResponse)
	err = json.NewDecoder(resp.Body).Decode(&response)
	if err != nil {
		return "", err
	}

	return response.URL, nil
}

func HandleRequest() (string, error) {
	token, err := decrypt(os.Getenv("QIITA_ACCESS_TOKEN"))
	if err != nil {
		return "", err
	}
	team, err := decrypt(os.Getenv("QIITA_TEAM_NAME"))
	if err != nil {
		return "", err
	}
	templateID, err := decrypt(os.Getenv("QIITA_TEAM_TEMPLATE_ID"))
	if err != nil {
		return "", err
	}

	client := &Client{
		Token:      token,
		Team:       team,
		TemplateID: templateID,
	}

	template, err := client.GetTemplate()
	if err != nil {
		return "", err
	}

	url, err := client.CreateItem(template.ExpandedTitle, template.ExpandedBody, template.ExpandedTags)
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("URL: %s", url), nil
}

func main() {
	lambda.Start(HandleRequest)
}
