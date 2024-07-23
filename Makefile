id := kali-now

image_tag := $(id)
container_name := $(id)
dockerfile := Dockerfile

shared_dir := shared

host_uid := $(shell id -u)
host_gid := $(shell id -g)
kvm_gid := $(shell stat -c '%g' /dev/kvm)
audio_gid := $(shell stat -c '%g' /dev/snd/timer)

entry_script_fragment := $$(nix-build nix -A entryScript)
interact_script_fragment := $$(nix-build nix -A interactScript)

.PHONY: none
none:

$(shared_dir):
	mkdir -p $@

.PHONY: build
build:
	docker build \
		-t $(image_tag) -f $(dockerfile) /var/empty

.PHONY: run
run: build | $(shared_dir)
	docker run -d -it --name $(container_name) \
		--cap-add=NET_ADMIN \
		--tmpfs /tmp \
		--device /dev/kvm \
		--device /dev/net/tun \
		--device /dev/snd \
		--mount type=bind,src=/nix/store,dst=/nix/store,ro \
		--mount type=bind,src=/nix/var/nix/db,dst=/nix/var/nix/db,ro \
		--mount type=bind,src=/nix/var/nix/daemon-socket,dst=/nix/var/nix/daemon-socket,ro \
		--mount type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix,ro \
		--mount type=bind,src=$(XAUTHORITY),dst=/host.Xauthority,ro \
		--mount type=bind,src=$(abspath $(shared_dir)),dst=/shared \
		--env HOST_UID=$(host_uid) \
		--env HOST_GID=$(host_gid) \
		--env KVM_GID=$(kvm_gid) \
		--env AUDIO_GID=$(audio_gid) \
		--env DISPLAY \
		$(image_tag) \
		$(entry_script_fragment)

.PHONY: r
r: build | $(shared_dir)
	docker run --rm -it \
		--name $(container_name) \
		--privileged \
		--tmpfs /tmp \
		--tmpfs /run \
		--device /dev/kvm \
		--device /dev/net/tun \
		--device /dev/snd \
		--mount type=bind,src=/nix/store,dst=/nix/store,ro \
		--mount type=bind,src=/nix/var/nix/db,dst=/nix/var/nix/db,ro \
		--mount type=bind,src=/nix/var/nix/daemon-socket,dst=/nix/var/nix/daemon-socket,ro \
		--mount type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix,ro \
		--mount type=bind,src=$(XAUTHORITY),dst=/host.Xauthority,ro \
		--mount type=bind,src=$(abspath $(shared_dir)),dst=/shared \
		--env DISPLAY \
		$(image_tag) \
		$$(nix-build nix -A containerInit)

.PHONY: exec
exec:
	docker exec -it \
		--user $(host_uid) \
		--env DISPLAY \
		$(container_name) \
		$(interact_script_fragment)

.PHONY: exec-as-root
exec-as-root:
	docker exec -it \
		--env DISPLAY \
		$(container_name) \
		$(interact_script_fragment)

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
