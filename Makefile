PROJECT  = serverless-qiita-team-template
SRC      ?= $(shell go list ./... | grep -v vendor)
TESTARGS ?= -v

deps:
	dep ensure
.PHONY: deps

test:
	go test $(SRC) $(TESTARGS)
.PHONY: test

fmt:
	go fmt $(SRC)
.PHONY: fmt

build:
	GOARCH=amd64 GOOS=linux go build -o build/$(PROJECT)
.PHONY: build

mb:
	aws s3 mb s3://$(PROJECT)

deploy:
	aws cloudformation package \
			--template-file sam.yml \
			--s3-bucket $(PROJECT) \
			--output-template-file .sam-output.yml
	aws cloudformation deploy \
			--template-file .sam-output.yml \
			--stack-name $(PROJECT) \
			--capabilities CAPABILITY_IAM
.PHONY: deploy
