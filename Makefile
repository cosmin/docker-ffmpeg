.PHONY: all
all: docker

.PHONY: docker
docker:
	docker build -t ffmpeg:latest .

.PHONY: push
push: docker
	docker tag ffmpeg:latest offbytwo/ffmpeg:latest
	docker push offbytwo/ffmpeg:latest
