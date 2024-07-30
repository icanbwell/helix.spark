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

shell:
	docker-compose run --rm --name helix_spark_dev dev sh

shell-minimal:
	docker run -it imranq2/helix.spark:minimal-local /bin/sh

update:
	docker-compose run --rm --name helix_spark_dev dev sh -c "rm -f Pipfile.lock && pipenv lock --dev --verbose"

history-server:
	docker run -v $PWD/spark-events:/tmp/spark-events -it imranq2/helix.spark:local sh
	docker run -v $PWD/spark-events:/tmp/spark-events -p 18080:18080 -it imranq2/helix.spark:local /opt/bitnami/spark/sbin/start-history-server.sh
	#docker run -v ./spark-events:/tmp/spark-events -it imranq2/helix.spark:local /opt/bitnami/spark/sbin/start-history-server.sh

# export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem -Dspark.history.fs.logDirectory=s3a://bwell-ingestion-stage/spark/events"
# ./start-history-server.sh
# ./spark-daemon.sh start org.apache.spark.deploy.history.HistoryServer -Dspark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem -Dspark.history.fs.logDirectory=s3a://bwell-ingestion-stage/spark/events

up:
	docker build -t imranq2/helix.spark:local . && \
	docker run --name spark_python --rm imranq2/helix.spark:local
