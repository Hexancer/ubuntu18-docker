## Usage
##
## make run && make init && make install && make user && make sshd
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
