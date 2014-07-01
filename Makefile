TOP_DIR = ../..
TARGET ?= /kb/deployment
DEPLOY_RUNTIME = /kb/runtime
SERVICE = awe_service
SERVICE_DIR = $(TARGET)/services/$(SERVICE)

GO_TMP_DIR = /tmp/go_build.tmp

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
	--define server_url=http://140.221.84.148:8000 \
	--define client_group=kbase \
	--define client_name=kbase-client \
	--define supported_apps=awe_qc.pl,awe_annotate.pl,awe_bowtie_screen.pl,awe_cluster_parallel.pl,awe_dereplicate.pl,awe_genecalling.pl,awe_preprocess.pl,awe_rna_blat.sh,awe_rna_search.pl,awe_blat.py,kmer-tool,drisee,consensus,unpack,histogram2json,drisee2json,kmer2json

else

APPS = $(shell ls $(TARGET)/bin | perl -e '@a = <>; chomp @a; print join(",", @a)')
SERVER_API_URL =
SERVER_SITE_URL =

ifneq ($(SERVER_API_URL),)
SERVER_API_PORT = $(shell perl -MURI -e "print URI->new('$(SERVER_API_URL)')->port")
endif

ifneq ($(SERVER_SITE_URL),)
SERVER_SITE_PORT = $(shell perl -MURI -e "print URI->new('$(SERVER_SITE_URL)')->port")
endif

MONGO_HOST = localhost
MONGO_DB = AWEDB
AWE_DIR = /disks/awe
AWE_CLIENT_GROUP = kbase
AWE_CLIENT_NAME = kbase-client
GLOBUS_TOKEN_URL = https://nexus.api.globusonline.org/goauth/token?grant_type=client_credentials
GLOBUS_PROFILE_URL = https://nexus.api.globusonline.org/users
ADMIN_LIST = 
ADMIN_AUTH = false

N_AWE_CLIENTS=1


	TPAGE_ARGS = --define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define kb_service_dir=$(SERVICE) \
	--define kb_service_name=$(SERVICE) \
	--define site_url=$(SERVER_SITE_URL) \
	--define api_url=$(SERVER_API_URL) \
	--define site_port=$(SERVER_SITE_PORT) \
	--define api_port=$(SERVER_API_PORT) \
	--define site_dir=$(AWE_DIR)/site \
	--define data_dir=$(AWE_DIR)/data \
	--define logs_dir=$(AWE_DIR)/logs \
	--define awfs_dir=$(AWE_DIR)/awfs \
	--define mongo_host=$(MONGO_HOST) \
	--define mongo_db=$(MONGO_DB) \
	--define work_dir=$(AWE_DIR)/work \
	--define server_url=$(SERVER_API_URL) \
	--define client_group=$(AWE_CLIENT_GROUP) \
	--define client_name=$(AWE_CLIENT_NAME) \
	--define supported_apps=$(APPS) \
	--define globus_token_url=$(GLOBUS_TOKEN_URL) \
	--define globus_profile_url=$(GLOBUS_PROFILE_URL) \
	--define admin_list=$(ADMIN_LIST) \
	--define admin_auth=$(ADMIN_AUTH) \
	--define n_awe_clients=$(N_AWE_CLIENTS)

endif

all: initialize 
include $(TOP_DIR)/tools/Makefile.common
include $(TOP_DIR)/tools/Makefile.common.rules

.PHONY : test


deploy: deploy-service deploy-client deploy-utils deploy-libs deploy-awe-libs

build-awe: $(BIN_DIR)/awe-server

build-libs:
	-mkdir -p lib/Bio/KBase/AWE
	$(TPAGE) $(TPAGE_ARGS) Constants.pm.tt > lib/Bio/KBase/AWE/Constants.pm

$(BIN_DIR)/awe-server: AWE/awe-server/awe-server.go
	rm -rf $(GO_TMP_DIR)
	mkdir -p $(GO_TMP_DIR)/src/github.com/MG-RAST
	cp -r AWE $(GO_TMP_DIR)/src/github.com/MG-RAST/
	export GOPATH=$(GO_TMP_DIR); go get -v github.com/MG-RAST/AWE/...
	cp -v $(GO_TMP_DIR)/bin/awe-server $(BIN_DIR)/awe-server
	cp -v $(GO_TMP_DIR)/bin/awe-client $(BIN_DIR)/awe-client

deploy-awe-libs:
	rsync --exclude '*.bak' -arv AWE/utils/lib/. $(TARGET)/lib/.

deploy-client: build-libs deploy-utils deploy-libs deploy-awe-libs

deploy-service: build-libs deploy-awe-server deploy-awe-client deploy-libs deploy-awe-libs

deploy-awe-server: all build-awe
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
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > service/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > service/stop_service
	cp service/start_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_service
	cp service/stop_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_service

deploy-awe-client: all build-awe
	cp $(BIN_DIR)/awe-client $(TARGET)/bin
	mkdir -p $(BIN_DIR) $(SERVICE_DIR) $(SERVICE_DIR)/conf $(SERVICE_DIR)/logs/awe $(SERVICE_DIR)/data/temp
	mkdir -p $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/work      
	chmod 777 $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/work
	id=1; while [ $$id -le $(N_AWE_CLIENTS) ] ; do \
	    $(TPAGE) $(TPAGE_ARGS) --define client_index=$$id awe_client.cfg.tt > awec.$$id.cfg; \
	    cp -v awec.$$id.cfg $(SERVICE_DIR)/conf/awec.$$id.cfg; \
	    id=`expr $$id + 1`; \
	done
	$(TPAGE) $(TPAGE_ARGS) awe_client.cfg.tt > awec.cfg
	cp -v awec.cfg $(SERVICE_DIR)/conf/awec.cfg
	$(TPAGE) $(TPAGE_ARGS) service/start_aweclient.tt > service/start_aweclient
	$(TPAGE) $(TPAGE_ARGS) service/stop_aweclient.tt > service/stop_aweclient
	cp service/start_aweclient $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_aweclient
	cp service/stop_aweclient $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_aweclient
	$(TPAGE) $(TPAGE_ARGS) service/monitrc.tt > service/monitrc
	cp service/monitrc $(SERVICE_DIR)/monitrc
	chmod go-rwx $(SERVICE_DIR)/monitrc

deploy-upstart:
	$(TPAGE) $(TPAGE_ARGS) init/awe.conf.tt > /etc/init/awe.conf
	$(TPAGE) $(TPAGE_ARGS) init/awe-client.conf.tt > /etc/init/awe-client.conf

initialize: AWE/site

AWE/site:
	git submodule init
	git submodule update

deploy-utils: SRC_PERL = $(wildcard AWE/utils/*.pl)
deploy-utils: deploy-scripts
