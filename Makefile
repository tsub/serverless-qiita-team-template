PROJECT  = serverless-qiita-team-template
SRC      ?= $(shell go list ./... | grep -v vendor)
TESTARGS ?= -v

define encrypt
	aws kms encrypt \
			--key-id "${KMS_KEY_ID}" \
			--query CiphertextBlob \
			--output text \
			--plaintext $(1)
endef

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
.PHONY: mb

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
					QiitaAccessToken="$(shell $(call encrypt, ${QIITA_ACCESS_TOKEN}))" \
					QiitaTeamName="$(shell $(call encrypt, ${QIITA_TEAM_NAME}))" \
					QiitaTeamTemplateId="$(shell $(call encrypt, ${QIITA_TEAM_TEMPLATE_ID}))" \
					KmsKeyId="${KMS_KEY_ID}" \
					ScheduleExpression="${SCHEDULE_EXPRESSION}"
.PHONY: deploy

destroy:
	aws cloudformation delete-stack \
			--stack-name $(PROJECT)
	aws s3 rb --force s3://$(PROJECT)
.PHONY: destroy

invoke_local:
	echo "" | sam local invoke \
			--parameter-values \
					QiitaAccessToken="$(shell $(call encrypt, ${QIITA_ACCESS_TOKEN}))",QiitaTeamName="$(shell $(call encrypt, ${QIITA_TEAM_NAME}))",QiitaTeamTemplateId="$(shell $(call encrypt, ${QIITA_TEAM_TEMPLATE_ID}))",KmsKeyId="${KMS_KEY_ID}",ScheduleExpression="${SCHEDULE_EXPRESSION}"
.PHONY: invoke_local
