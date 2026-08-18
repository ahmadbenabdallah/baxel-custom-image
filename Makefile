IMAGE_NAME := hermes-agent-sandbox

build:
	docker build -t $(IMAGE_NAME) .

run:
	docker run --rm -it -p 8080:8080 -p 8000:8000 $(IMAGE_NAME)

push:
	bl push

deploy:
	bl deploy
