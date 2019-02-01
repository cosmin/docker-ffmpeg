.PHONY: all release experimental push
all: stable

stable:
	$(eval VERSION=stable)
	docker build -t ffmpeg:$(VERSION) .
experimental:
	$(eval VERSION=experimental)
	docker build --build-arg ffmpeg_version=snapshot --build-arg libaom_version=master --build-arg libvpx_version=master -t ffmpeg:$(VERSION) .
push:
	docker tag ffmpeg:$(VERSION) offbytwo/ffmpeg:$(VERSION)
	docker push offbytwo/ffmpeg:$(VERSION)
