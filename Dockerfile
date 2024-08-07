# Build stage for maven packages
FROM maven:3.8.1-openjdk-15-slim AS build

COPY pom.xml /tmp/bsights-engine-spark/

# get dependencies for bsights-engine-spark
RUN cd /tmp/bsights-engine-spark \
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
    && mvn dependency:resolve-plugins \
    && ls /tmp/spark/jars

# Build stage for pip packages
FROM python:3.12-slim AS python_packages

RUN apt-get update && \
    apt-get install -y git && \
    pip install pipenv

# Essential updates for build to succeed on arm64:
RUN apt update && \
    apt install -y build-essential

RUN python --version && \
    python -m pip install --upgrade --no-cache-dir pip && \
    python -m pip install --no-cache-dir wheel && \
    python -m pip install --no-cache-dir pre-commit && \
    python -m pip install --no-cache-dir pipenv

ENV PYTHONPATH=/helix.pipelines
ENV PYTHONPATH="/opt/project:${PYTHONPATH}"

COPY Pipfile* /helix.pipelines/
WORKDIR /helix.pipelines

# RUN pip debug --verbose
RUN pipenv sync --system --extra-pip-args="--prefer-binary"

#RUN pip list -v

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
ENV PYTHONPATH="/opt/project:${PYTHONPATH}"
ENV CLASSPATH=/helix.pipelines/jars:$CLASSPATH

COPY Pipfile* /helix.pipelines/
WORKDIR /helix.pipelines

COPY --from=build /tmp/spark/jars /opt/spark/jars

RUN mkdir -p /usr/local/lib/python3.12/site-packages/

COPY --from=python_packages /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/

# get the shell commands for these packages also
#COPY --from=python_packages /usr/local/bin/pytest /usr/local/bin/pytest
#COPY --from=python_packages /helix.pipelines/Pipfile* /helix.pipelines/

RUN ls -halt /opt/spark/jars/

COPY ./conf/* /opt/spark/conf/

RUN ls -halt /opt/spark/jars/

COPY ./test.py ./

ENV AWS_DEFAULT_REGION=us-east-1
ENV AWS_REGION=us-east-1

ENV HADOOP_CONF_DIR=/opt/spark/conf

COPY minimal_entrypoint.sh /opt/minimal_entrypoint.sh

RUN chmod a+x /opt/minimal_entrypoint.sh

USER root
# install python 3.12 - it's not available in normal ubuntu repositories
# https://github.com/deadsnakes/issues/issues/53
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 && \
    echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu/ jammy main" | tee /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-lunar.list && \
    apt-get update && apt-get install -y python3.12 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope

RUN echo "I'm building for platform=$TARGETPLATFORM, architecture=$TARGETARCH, variant=$TARGETVARIANT"
# this command below fails in Github Runner
RUN if [ "$TARGETARCH" = "amd64" ] ;  \
        then /opt/spark/bin/spark-submit  \
        --conf "spark.jars=/opt/spark/jars/*" \
        --master local[*] test.py;  \
    fi

# Run as non-root user
# https://spark.apache.org/docs/latest/running-on-kubernetes.html#user-identity
USER 185
