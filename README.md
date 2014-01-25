awe_service
===========
Enables deployment of AWE server and clients within the kbase release environment.

The following are instructions on how to deploy the AWE service in KBase from launching a fresh KBase instance to starting the service...

- Create a security group for your AWE server (this isn't required with the test ports in the Makefile but makes it convenient if you want to change those ports later)
- Using this security group and your key, launch a KBase instance
- Get the code:
sudo -s
cd /kb
git clone kbase@git.kbase.us:dev_container.git
cd dev_container/modules
git clone kbase@git.kbase.us:awe_service.git
cd awe_service

- Edit the Makefile if you would like to configure the IP and port numbers for your AWE server.

- Create a mongo data directory on the mounted drive and symbolic link to point to it:
(NOTE: mongodb is only required if you are deploying the AWE server, not the client)
cd /mnt
mkdir db
cd /
mkdir data
cd data/
ln -s /mnt/db .

- Start mongod (preferably in a screen session):
cd /kb/dev_container
./bootstrap /kb/runtime
source user-env.sh
mongod

(NOTE: mongod needs a few minutes to start.  Once you can run "mongo" from the command line and connect to mongo db, then proceed with deploying AWE)
- Deploy AWE:
cd /kb/dev_container
./bootstrap /kb/runtime
source user-env.sh
make
make deploy

- Start/Stop AWE Server:
/kb/deployment/services/awe_service/start_service
/kb/deployment/services/awe_service/stop_service

- After deployment has completed, if you've associated an IP with your instance you should be able to confirm that AWE is running by going to either url below (ports are defined in Makefile prior to deployment):
site ->  http://[AWE Server IP]:7079/
api  ->  http://[AWE Server IP]:7080/

- Start/Stop AWE Client:
/kb/deployment/services/awe_service/start_aweclient
/kb/deployment/services/awe_service/stop_aweclient
(note: before start awe-client, make sure the fields in awe_client.cfg.tt have been configured with proper values by modifying Makefile.)
