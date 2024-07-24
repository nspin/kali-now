id := kali-now

image_tag := $(id)
container_name := $(id)
dockerfile := Dockerfile

shared_dir := shared

# TODO check that these match the container system
host_uid := $(shell id -u)
host_gid := $(shell id -g)
kvm_gid := $(shell stat -c '%g' /dev/kvm)
audio_gid := $(shell stat -c '%g' /dev/snd/timer)

container_init := $$(nix-build nix -A containerInit)
container_bash := /run/current-system/sw/bin/bash

.PHONY: none
none:

$(shared_dir):
	mkdir -p $@

.PHONY: rm-shared
rm-shared:
	rm -rf $(shared_dir)

.PHONY: build
build:
	docker build \
		-t $(image_tag) -f $(dockerfile) /var/empty

.PHONY: run
run: build | $(shared_dir)
	docker run -it --name $(container_name) \
		--rm \
		--privileged \
		--tmpfs /tmp \
		--tmpfs /run \
		--mount type=bind,src=/dev,dst=/dev \
		--mount type=bind,src=/nix/store,dst=/nix/store,ro \
		--mount type=bind,src=/nix/var/nix/db,dst=/nix/var/nix/db,ro \
		--mount type=bind,src=/nix/var/nix/daemon-socket,dst=/nix/var/nix/daemon-socket,ro \
		--mount type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix,ro \
		--mount type=bind,src=$(abspath $(shared_dir)),dst=/shared \
		$(image_tag) \
		$(container_init)

.PHONY: exec
exec:
	container_xauthority=$$(nix-build nix -A containerXauthority)/bin/container-xauthority && \
	$$container_xauthority env-host \
	docker exec -it \
		--user $(host_uid) \
		--env XAUTHORITY_CONTENTS \
		--env DISPLAY \
		$(container_name) \
		$$container_xauthority env-container $(container_bash)

.PHONY: exec-as-root
exec-as-root:
	docker exec -it \
		--env DISPLAY \
		$(container_name) \
		$(container_bash)

.PHONY: rm-container
rm-container:
	for id in $$(docker ps -aq -f "name=^$(container_name)$$"); do \
		docker rm -f $$id; \
	done

.PHONY: show-logs
show-logs:
	for id in $$(docker ps -aq -f "name=^$(container_name)$$"); do \
		docker logs $$id; \
	done
