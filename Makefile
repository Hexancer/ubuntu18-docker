## Usage
##
## make run && make init && make install && make user && make sshd
## 
## make upgrade-gcc && make upgrade-cmake 
##
## Specify the following options from command-line as needed
##

IMAGE := watchback
TAG   := latest

CONFIG_MK ?= Makefile.cfg
include $(CONFIG_MK)

BACKUP_SRC := /etc /var/log  ## Set your backup directory here
TTY_OPTS    := -it
DETACH_OPTS := -d
NET_OPTS    := #--network=host
VOL_OPTS    := $(addprefix -v , $(VOLS))
PORT_OPTS   := $(addprefix -p , $(PORTS))
EXPOSE_OPTS := $(addprefix --expose , $(EXPOSES))

override RUN_OPTS += $(TTY_OPTS) $(DETACH_OPTS) $(NET_OPTS) $(VOL_OPTS) $(PORT_OPTS) $(EXPOSE_OPTS)

run:
	docker run $(RUN_OPTS) --name $(NAME) $(IMAGE):$(TAG)

start:
	docker start $(NAME)

stop:
	docker stop $(NAME)

rm:
	docker rm $(NAME)

exec:
	docker exec $(TTY_OPTS) $(NAME) $(PROG)

init:


install:
	docker exec $(NAME) apt install -y $(PKGS) 

user:
	$(eval PASSWD := $(shell cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 18))
	@echo "$(USER):$(PASSWD)" | tee /dev/stderr
	docker exec $(NAME) groupadd wheel
	docker exec $(NAME) useradd $(USER) -m -G wheel -s $(SH) --password $(shell perl -e "print crypt(\"$(PASSWD)\","password")")

passwd:
	$(eval PASSWD := $(shell cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 18))
	@echo "$(USER):$(PASSWD)" | tee /dev/stderr |\
	docker exec -i $(NAME) chpasswd

sshdgenkeys: ./ssh/ssh_host_ecdsa_key ./ssh/ssh_host_ed25519_key ./ssh/ssh_host_rsa_key
./ssh/ssh_host_ecdsa_key ./ssh/ssh_host_ed25519_key ./ssh/ssh_host_rsa_key:
	docker exec $(NAME) bash -c "/usr/bin/ssh-keygen -A"

sshd: sshdgenkeys
	docker exec $(NAME) mkdir -p /run/sshd
	docker exec $(NAME) chmod 0755 /run/sshd
	docker exec $(DETACH_OPTS) $(NAME) /usr/sbin/sshd -D

backup:
	@echo "Backing up container $(NAME)..."
	@mkdir -p ./backups
	@docker exec $(NAME) tar czf - $(BACKUP_SRC) > ./backups/$(NAME)-backup-$(shell date +%Y%m%d%H%M%S).tar.gz
	@echo "Backup completed. Saved to ./backups."

export-container:
	@mkdir -p ./exports
	@docker export $(NAME) > ./exports/$(NAME)-filesystem-$(shell date +%Y%m%d%H%M%S).tar
	@echo "Exported container $(NAME) filesystem to ./exports/$(NAME)-filesystem-<timestamp>.tar"


export-image:
	@mkdir -p ./exports
	@docker save $(IMAGE):$(TAG) > ./exports/$(IMAGE)-$(TAG)-$(shell date +%Y%m%d%H%M%S).tar
	@echo "Exported image $(IMAGE):$(TAG) to ./exports/$(IMAGE)-$(TAG)-<timestamp>.tar"

# make import-container FILE=<filename.tar> IMAGE=<image_name> TAG=<tag>
import-container:
	@docker import ./exports/$(FILE) $(IMAGE):$(TAG)
	@echo "Imported container filesystem from ./exports/$(FILE) as $(IMAGE):$(TAG)"

# make import-image FILE=<filename.tar> 
import-image:
	@docker load < ./exports/$(FILE)
	@echo "Imported image from ./exports/$(FILE)"

## Upgrade CMake to version 3.22 inside Docker container
upgrade-cmake:
	@echo "Upgrading CMake to version 3.22 inside container..."
	@CMAKE_VERSION=3.22.4
	@CMAKE_DIR=cmake-3.22.4
	@CMAKE_FILE=cmake-3.22.4-linux-x86_64.tar.gz
	@docker exec $(NAME) bash -c "wget https://github.com/Kitware/CMake/releases/download/v3.22.4/cmake-3.22.4-linux-x86_64.tar.gz"
	@docker exec $(NAME) bash -c "tar -xvf cmake-3.22.4-linux-x86_64.tar.gz"
	@docker exec $(NAME) bash -c "mv cmake-3.22.4-linux-x86_64 /usr/local/"
	@docker exec $(NAME) bash -c "ln -sf /usr/local/cmake-3.22.4-linux-x86_64/bin/* /usr/local/bin/"
	@docker exec $(NAME) bash -c "rm cmake-3.22.4-linux-x86_64.tar.gz"
	@echo "CMake has been upgraded to version 3.22.4."
	@docker exec $(NAME) bash -c "cmake --version"

## Upgrade GCC to version 11 inside Docker container
upgrade-gcc:
	@echo "Upgrading GCC to version 11 inside container..."
	@docker exec $(NAME) bash -c "apt update"
	@docker exec $(NAME) bash -c "apt install -y software-properties-common"
	@docker exec $(NAME) bash -c "add-apt-repository ppa:ubuntu-toolchain-r/test -y"
	@docker exec $(NAME) bash -c "apt update"
	@docker exec $(NAME) bash -c "apt install -y gcc-11 g++-11"
	@docker exec $(NAME) bash -c "update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100"
	@docker exec $(NAME) bash -c "update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100"
	@docker exec $(NAME) bash -c "update-alternatives --set gcc /usr/bin/gcc-11"
	@docker exec $(NAME) bash -c "update-alternatives --set g++ /usr/bin/g++-11"
	@echo "GCC has been upgraded to version 11."
	@docker exec $(NAME) bash -c "gcc --version"


