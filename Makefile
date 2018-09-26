.PHONY: all
all: docker

.PHONY: docker
docker:
	docker build -t ffmpeg:latest .

.PHONY: push
push: docker
	docker tag ffmpeg:latest offbytwo/video-tools:latest
	docker push offbytwo/video-tools:latest
