.PHONY: all release experimental push
all: stable

stable:
	docker build -t ffmpeg:nvenc .
push:
	docker tag ffmpeg:$(VERSION) offbytwo/ffmpeg:$(VERSION)
	docker push offbytwo/ffmpeg:$(VERSION)
