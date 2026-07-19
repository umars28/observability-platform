IMAGE ?= demo-blog-web:local

.PHONY: build install dev

build:
	docker build -t $(IMAGE) .

install:
	npm install

dev:
	npm run dev
