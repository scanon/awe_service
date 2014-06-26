TOP_DIR = ../..
TARGET ?= /kb/deployment
DEPLOY_RUNTIME = /kb/runtime
SERVICE = awe_service
SERVICE_DIR = $(TARGET)/services/$(SERVICE)
SERVER_URL = http://localhost:8000
GO_TMP_DIR = /tmp/go_build.tmp
CLIENT_GROUP = kbase
APP_LIST = '*'
PRODUCTION = 0 

ifeq ($(PRODUCTION), 1)
	AWE_DIR = /disk0/awe
	TPAGE_ARGS = --define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define site_url=https://kbase.us/services/awe \
	--define api_url=https://kbase.us/services/awe-api \
	--define site_port=7106 \
	--define api_port=7107 \
	--define site_dir=$(AWE_DIR)/site \
	--define data_dir=$(AWE_DIR)/data \
	--define logs_dir=$(AWE_DIR)/logs \
	--define awfs_dir=$(AWE_DIR)/awfs \
	--define mongo_host=localhost \
	--define mongo_db=AWEDB \
	--define work_dir=$(AWE_DIR)/work \
	--define server_url=$(SERVER_URL) \
	--define client_group=$(CLIENT_GROUP) \
	--define client_name=$(CLIENT_GROUP)-client \
	--define supported_apps=$(APP_LIST)
else
	AWE_DIR = /mnt/awe
	TPAGE_ARGS = --define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define site_url= \
	--define api_url= \
	--define site_port=7079 \
	--define api_port=7080 \
	--define site_dir=$(AWE_DIR)/site \
	--define data_dir=$(AWE_DIR)/data \
	--define logs_dir=$(AWE_DIR)/logs \
	--define awfs_dir=$(AWE_DIR)/awfs \
	--define mongo_host=localhost \
	--define mongo_db=AWEDB \
	--define work_dir=$(AWE_DIR)/work \
	--define server_url=$(SERVER_URL) \
	--define client_group=$(CLIENT_GROUP) \
	--define client_name=$(CLIENT_GROUP)-client \
	--define supported_apps=$(APP_LIST)
endif

all: initialize build-awe |
include $(TOP_DIR)/tools/Makefile.common
include $(TOP_DIR)/tools/Makefile.common.rules

.PHONY : test

clean:
	if [ -f $(SERVICE_DIR)/stop_service ]; then $(SERVICE_DIR)/stop_service; fi;
	if [ -f $(SERVICE_DIR)/stop_aweclient ]; then $(SERVICE_DIR)/stop_aweclient; fi;
	-rm -f $(BIN_DIR)/awe-server
	-rm -f $(BIN_DIR)/awe-client
	-rm -rf $(SERVICE_DIR)
	-rm -rf $(AWE_DIR)

build-awe: $(BIN_DIR)/awe-server

build-update: update build-awe |

$(BIN_DIR)/awe-server: AWE/awe-server/awe-server.go
	rm -rf $(GO_TMP_DIR)
	mkdir -p $(GO_TMP_DIR)/src/github.com/MG-RAST
	cp -r AWE $(GO_TMP_DIR)/src/github.com/MG-RAST/
	export GOPATH=$(GO_TMP_DIR); go get -v github.com/MG-RAST/AWE/...
	cp -v $(GO_TMP_DIR)/bin/awe-server $(BIN_DIR)/awe-server
	cp -v $(GO_TMP_DIR)/bin/awe-client $(BIN_DIR)/awe-client

deploy: deploy-service deploy-client deploy-utils deploy-libs

deploy-service: build-dirs
	cp $(BIN_DIR)/awe-server $(TARGET)/bin
	$(TPAGE) $(TPAGE_ARGS) awe_server.cfg.tt > awe.cfg
	$(TPAGE) $(TPAGE_ARGS) AWE/site/js/config.js.tt > AWE/site/js/config.js
	cp -v -r AWE/site $(AWE_DIR)/site
	mkdir -p $(BIN_DIR) $(SERVICE_DIR) $(SERVICE_DIR)/conf $(SERVICE_DIR)/logs/awe $(SERVICE_DIR)/data/temp
	cp -v awe.cfg $(SERVICE_DIR)/conf/awe.cfg
	cp -r AWE/templates/awf_templates/* $(AWE_DIR)/awfs/
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > service/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > service/stop_service
	cp service/start_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_service
	cp service/stop_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_service

deploy-client: build-dirs
	cp $(BIN_DIR)/awe-client $(TARGET)/bin
	$(TPAGE) $(TPAGE_ARGS) awe_client.cfg.tt > awec.cfg
	mkdir -p $(BIN_DIR) $(SERVICE_DIR) $(SERVICE_DIR)/conf $(SERVICE_DIR)/logs/awe $(SERVICE_DIR)/data/temp
	cp -v awec.cfg $(SERVICE_DIR)/conf/awec.cfg
	$(TPAGE) $(TPAGE_ARGS) service/start_aweclient.tt > service/start_aweclient
	$(TPAGE) $(TPAGE_ARGS) service/stop_aweclient.tt > service/stop_aweclient
	cp service/start_aweclient $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_aweclient
	cp service/stop_aweclient $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_aweclient

build-dirs:
	mkdir -p $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/awfs $(AWE_DIR)/work
	chmod 777 $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/awfs $(AWE_DIR)/work

deploy-libs:
	rsync --exclude '*.bak' -arv AWE/utils/lib/. $(TARGET)/lib/.

deploy-upstart:
	$(TPAGE) $(TPAGE_ARGS) init/awe.conf.tt > /etc/init/awe.conf
	$(TPAGE) $(TPAGE_ARGS) init/awe-client.conf.tt > /etc/init/awe-client.conf

initialize: AWE/site

update:
	cd AWE; git pull origin master

AWE/site:
	git submodule init
	git submodule update

deploy-utils: SRC_PERL = $(wildcard AWE/utils/*.pl)
deploy-utils: deploy-scripts
