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
			--template-file template.yml \
			--s3-bucket $(PROJECT) \
			--output-template-file .template-output.yml
	aws cloudformation deploy \
			--template-file .template-output.yml \
			--stack-name $(PROJECT) \
			--capabilities CAPABILITY_IAM \
			--parameter-overrides \
					QiitaAccessToken="${QIITA_ACCESS_TOKEN}" \
					QiitaTeamName="${QIITA_TEAM_NAME}" \
					QiitaTeamTemplateId="${QIITA_TEAM_TEMPLATE_ID}" \
					KmsKeyId="${KMS_KEY_ID}" \
					ScheduleExpression="${SCHEDULE_EXPRESSION}"
.PHONY: deploy
