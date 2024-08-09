LANG=en_US.utf-8

export LANG


Pipfile.lock: Pipfile
	docker compose run --rm --name helix_spark_dev dev sh -c "rm -f Pipfile.lock && pipenv lock --dev"

update: Pipfile.lock  ## Updates all the packages using Pipfile
	docker compose run --rm --name helix_spark_dev dev pipenv sync && \
	make devdocker && \
	echo "In PyCharm, do File -> Invalidate Caches/Restart to refresh" && \
	echo "If you encounter issues with remote sources being out of sync, click on the 'Remote Python' feature on" && \
	echo "the lower status bar and reselect the same interpreter and it will rebuild the remote source cache." && \
	echo "See this link for more details:" && \
	echo "https://intellij-support.jetbrains.com/hc/en-us/community/posts/205813579-Any-way-to-force-a-refresh-of-external-libraries-on-a-remote-interpreter-?page=2#community_comment_360002118020"

devdocker: ## Builds the docker for dev
	docker compose build --parallel

up:
	docker build -t imranq2/helix.spark:local . && \
	docker run --name spark_python --rm imranq2/helix.spark:local

down: ## Brings down all the services in docker-compose
	export DOCKER_CLIENT_TIMEOUT=300 && export COMPOSE_HTTP_TIMEOUT=300
	docker compose down --remove-orphans && \
	docker system prune -f

clean: down
	docker image ls | grep "helixspark" | awk '{print $$1}' | xargs docker image rm
	docker image ls | grep "helixspark" | awk '{print $$1}' | xargs docker image rm || true
	docker volume ls | grep "helixspark" | awk '{print $$2}' | xargs docker volume rm


build_init:
	docker image rm imranq2/helix.spark:local || echo "no image"
	# docker build -t imranq2/helix.spark:local .
	docker buildx create --use

build:
	#docker buildx build --platform=linux/amd64 --progress=plain -t imranq2/helix.spark:local .
	docker build -t imranq2/helix.spark:local .

build_all:
	#docker image rm imranq2/helix.spark:local || echo "no image"
	docker buildx build --platform=linux/amd64 -t imranq2/helix.spark:local .
	#docker buildx build --platform=linux/arm64 -t imranq2/helix.spark:local .

build-minimal:
	docker image rm imranq2/helix.spark:minimal-local || echo "no image"
#	docker buildx build --platform=linux/amd64 -t imranq2/helix.spark:local .
	docker buildx build --platform=linux/arm64 -f minimal.Dockerfile -t imranq2/helix.spark:minimal-local .
#	docker buildx build --platform=linux/amd64 -f minimal.Dockerfile -t imranq2/helix.spark:minimal-local .

build-precommit:
	docker build -t imranq2/helix.spark:precommit -f pre-commit.Dockerfile .

shell:
	docker compose run --rm --name helix_spark_dev dev sh

shell-minimal:
	docker run -it imranq2/helix.spark:minimal-local /bin/sh

history-server:
	docker run -v $PWD/spark-events:/tmp/spark-events -it imranq2/helix.spark:local sh
	docker run -v $PWD/spark-events:/tmp/spark-events -p 18080:18080 -it imranq2/helix.spark:local /opt/bitnami/spark/sbin/start-history-server.sh
	#docker run -v ./spark-events:/tmp/spark-events -it imranq2/helix.spark:local /opt/bitnami/spark/sbin/start-history-server.sh

# export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem -Dspark.history.fs.logDirectory=s3a://bwell-ingestion-stage/spark/events"
# ./start-history-server.sh
# ./spark-daemon.sh start org.apache.spark.deploy.history.HistoryServer -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem -Dspark.history.fs.logDirectory=s3a://bwell-ingestion-stage/spark/events
