# Build stage for maven packages
FROM maven:3.8.1-openjdk-15-slim AS build
# get dependencies for bsights-engine-spark
RUN mkdir /tmp/bsights-engine-spark \
    && cd /tmp/bsights-engine-spark \
    && mkdir /tmp/spark \
    && mkdir /tmp/spark/jars \
    && ls /tmp/spark/jars \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=mysql:mysql-connector-java:8.0.24 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:spark-sql-kafka-0-10_2.12:3.3.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=io.delta:delta-core_2.12:2.3.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=io.delta:delta-storage:2.3.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.johnsnowlabs.nlp:spark-nlp_2.12:4.2.2 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.amazonaws:aws-java-sdk-bundle:1.12.339 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.hadoop:hadoop-aws:3.2.2 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:spark-hadoop-cloud_2.12:3.3.1 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.databricks:spark-xml_2.12:0.15.0 \
    && ls /tmp/spark/jars

# Run stage
FROM imranq2/spark-py:java17-3.3.0.16
USER root

ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETVARIANT

# install system packages
RUN /usr/bin/python3 --version && \
    /usr/bin/python3 -m pip install --upgrade --no-cache-dir pip && \
    /usr/bin/python3 -m pip install --no-cache-dir wheel && \
    /usr/bin/python3 -m pip install --no-cache-dir pre-commit && \
    /usr/bin/python3 -m pip install --no-cache-dir pipenv

ENV PYTHONPATH=/helix.pipelines
ENV PYTHONPATH "/opt/project:${PYTHONPATH}"
ENV CLASSPATH=/helix.pipelines/jars:$CLASSPATH

COPY Pipfile* /helix.pipelines/
WORKDIR /helix.pipelines
COPY --from=build /tmp/spark/jars /opt/spark/jars

RUN mkdir -p /usr/local/lib/python3.10/site-packages/

COPY ./conf/* /opt/spark/conf/
COPY ./test.py ./

ENV AWS_DEFAULT_REGION=us-east-1
ENV AWS_REGION=us-east-1
ENV HADOOP_CONF_DIR=/opt/spark/conf

COPY minimal_entrypoint.sh /opt/minimal_entrypoint.sh

RUN chmod a+x /opt/minimal_entrypoint.sh

USER root
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

RUN echo "I'm building for platform=$TARGETPLATFORM, architecture=$TARGETARCH, variant=$TARGETVARIANT"
# this command below fails in Github Runner
RUN if [ "$TARGETARCH" = "amd64" ] ; then /opt/spark/bin/spark-submit --master local[*] test.py; fi
