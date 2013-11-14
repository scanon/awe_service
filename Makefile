TOP_DIR = ../..
TARGET ?= /kb/deployment
DEPLOY_RUNTIME = /kb/runtime
SERVICE = awe_service
SERVICE_DIR = $(TARGET)/services/$(SERVICE)

GO_TMP_DIR = /tmp/go_build.tmp

PRODUCTION = 1 

ifeq ($(PRODUCTION), 1)
	AWE_DIR = /disk0/awe
	TPAGE_ARGS = --define kb_top=$(TARGET) \
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
	--define server_url=http://140.221.84.148:8000 \
	--define client_group=kbase \
	--define client_name=kbase-client \
	--define supported_apps=awe_qc.pl,awe_annotate.pl,awe_bowtie_screen.pl,awe_cluster_parallel.pl,awe_dereplicate.pl,awe_genecalling.pl,awe_preprocess.pl,awe_rna_blat.sh,awe_rna_search.pl,awe_blat.py
else
	AWE_DIR = /mnt/awe
	TPAGE_ARGS = --define kb_top=$(TARGET) \
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
	--define server_url=http://140.221.84.148:8000 \
	--define client_group=kbase \
	--define client_name=kbase-client \
	--define supported_apps=awe_qc.pl,awe_annotate.pl,awe_bowtie_screen.pl,awe_cluster_parallel.pl,awe_dereplicate.pl,awe_genecalling.pl,awe_preprocess.pl,awe_rna_blat.sh,awe_rna_search.pl,awe_blat.py
endif

include $(TOP_DIR)/tools/Makefile.common

.PHONY : test

all: initialize build-awe

deploy: deploy-service deploy-client deploy-utils

build-awe: $(BIN_DIR)/awe-server

$(BIN_DIR)/awe-server: AWE/awe-server/awe-server.go
	rm -rf $(GO_TMP_DIR)
	mkdir -p $(GO_TMP_DIR)/src/github.com/MG-RAST
	cp -r AWE $(GO_TMP_DIR)/src/github.com/MG-RAST/
	export GOPATH=$(GO_TMP_DIR); go get -v github.com/MG-RAST/AWE/...
	cp -v $(GO_TMP_DIR)/bin/awe-server $(BIN_DIR)/awe-server
	cp -v $(GO_TMP_DIR)/bin/awe-client $(BIN_DIR)/awe-client

deploy-service: all
	cp $(BIN_DIR)/awe-server $(TARGET)/bin
	$(TPAGE) $(TPAGE_ARGS) awe_server.cfg.tt > awe.cfg
	$(TPAGE) $(TPAGE_ARGS) AWE/site/js/config.js.tt > AWE/site/js/config.js
	mkdir -p $(AWE_DIR)/site $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/awfs
	chmod 777  $(AWE_DIR)/site $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/awfs
	rm -r $(AWE_DIR)/site
	cp -v -r AWE/site $(AWE_DIR)/site
	mkdir -p $(BIN_DIR) $(SERVICE_DIR) $(SERVICE_DIR)/conf $(SERVICE_DIR)/logs/awe $(SERVICE_DIR)/data/temp
	cp -v awe.cfg $(SERVICE_DIR)/conf/awe.cfg
	cp -r AWE/templates/awf_templates/* $(AWE_DIR)/awfs/
	cp service/start_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_service
	cp service/stop_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_service
	$(TPAGE) $(TPAGE_ARGS) init/awe.conf.tt > /etc/init/awe.conf

deploy-client: all
	cp $(BIN_DIR)/awe-client $(TARGET)/bin
	$(TPAGE) $(TPAGE_ARGS) awe_client.cfg.tt > awec.cfg
	mkdir -p $(BIN_DIR) $(SERVICE_DIR) $(SERVICE_DIR)/conf $(SERVICE_DIR)/logs/awe $(SERVICE_DIR)/data/temp
	mkdir -p $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/work      
	chmod 777 $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/work
	cp -v awec.cfg $(SERVICE_DIR)/conf/awec.cfg
	cp service/start_aweclient $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_aweclient
	cp service/stop_aweclient $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_aweclient
	$(TPAGE) $(TPAGE_ARGS) init/awe-client.conf.tt > /etc/init/awe-client.conf

initialize: AWE/site

AWE/site:
	git submodule init
	git submodule update

include $(TOP_DIR)/tools/Makefile.common.rules

deploy-utils: SRC_PERL = $(wildcard AWE/utils/*.pl)
deploy-utils: deploy-scripts
