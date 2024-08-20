LANG=en_US.utf-8

export LANG

up:
	docker build -f minimal.Dockerfile -t imranq2/helix.spark:minimal-local . && \
	docker run --name helix_spark_dev --rm imranq2/helix.spark:minimal-local

down: ## Brings down all the services in docker-compose
	export DOCKER_CLIENT_TIMEOUT=300 && export COMPOSE_HTTP_TIMEOUT=300
	docker compose down --remove-orphans && \
	docker system prune -f

clean: down
	docker image ls | grep "helixspark" | awk '{print $$1}' | xargs docker image rm
	docker image ls | grep "helixspark" | awk '{print $$1}' | xargs docker image rm || true
	docker volume ls | grep "helixspark" | awk '{print $$2}' | xargs docker volume rm

build_init:
	docker image rm imranq2/helix.spark:minimal-local || echo "no image"
	docker buildx create --use

build:
	#docker image rm imranq2/helix.spark:minimal-local || echo "no image"
	docker buildx build --progress=plain --platform=linux/arm64 -f minimal.Dockerfile -t imranq2/helix.spark:minimal-local .

build-precommit-slim:
	docker build -f pre-commit-slim.Dockerfile -t imranq2/helix.spark:precommit-slim .

shell:
	docker compose run --rm --name helix_spark_dev dev sh

history-server:
	docker run -v $PWD/spark-events:/tmp/spark-events -it imranq2/helix.spark:minimal-local sh
	docker run -v $PWD/spark-events:/tmp/spark-events -p 18080:18080 -it imranq2/helix.spark:minimal-local /opt/bitnami/spark/sbin/start-history-server.sh
	#docker run -v ./spark-events:/tmp/spark-events -it imranq2/helix.spark:minimal-local /opt/bitnami/spark/sbin/start-history-server.sh

# export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem -Dspark.history.fs.logDirectory=s3a://bwell-ingestion-stage/spark/events"
# ./start-history-server.sh
# ./spark-daemon.sh start org.apache.spark.deploy.history.HistoryServer -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem -Dspark.history.fs.logDirectory=s3a://bwell-ingestion-stage/spark/events
