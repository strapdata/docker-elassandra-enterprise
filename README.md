# docker-elassandra-enterprise

Build elassandra-enterprise docker image

## build

	ENTERPRISE_PLUGIN_DIR=/Users/vroyer/dev/git/strapdata/strapack BASE_IMAGE=strapdata/elassandra-rc:6.2.3.7-rc1 DOCKER_PUBLISH=true ./build.sh 


## Visit elassandra image 

Run bash in image:

	docker run --rm -it --entrypoint /bin/bash strapdata/elassandra-enterprise:6.2.3.7-rc1

## run elassandra

Lauch an Elassandra node:
	
	docker run -d strapdata/elassandra-enterprise:6.2.3.7-rc1
	docker exec -it <container_id> bash