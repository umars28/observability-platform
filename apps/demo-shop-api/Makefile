IMAGE ?= demo-shop-api:local

.PHONY: build test lint tidy

build:
	docker build -t $(IMAGE) .

test:
	go test ./...

tidy:
	go mod tidy

lint:
	go vet ./...
	gofmt -l . | grep -q . && (echo "gofmt errors" && exit 1) || true
