# Build stage for maven packages
FROM maven:3.9.9-eclipse-temurin-17-focal AS build

# get dependencies for bsights-engine-spark
RUN mkdir /tmp/bsights-engine-spark \
    && cd /tmp/bsights-engine-spark \
#    && curl https://raw.githubusercontent.com/icanbwell/bsights-engine-spark/main/pom.xml -o pom.xml \
    && mkdir /tmp/spark \
    && mkdir /tmp/spark/jars \
#    && mvn dependency:copy-dependencies -DoutputDirectory=/tmp/spark/jars -Dhttps.protocols=TLSv1.2 \
    && ls /tmp/spark/jars \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:spark-sql-kafka-0-10_2.12:3.4.2 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:spark-hadoop-cloud_2.12:3.5.1 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.hadoop:hadoop-aws:3.4.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=io.delta:delta-spark_2.12:3.2.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=io.delta:delta-storage:3.2.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.johnsnowlabs.nlp:spark-nlp_2.12:5.4.1 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.amazonaws:aws-java-sdk-bundle:1.12.772 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.databricks:spark-xml_2.12:0.18.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:spark-streaming-kafka-0-10_2.12:3.5.1 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:spark-token-provider-kafka-0-10_2.12:3.5.2 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.commons:commons-pool2:2.12.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.kafka:kafka-clients:3.8.1 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.7.1:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=mysql:mysql-connector-java:8.0.33 \
    && ls /tmp/spark/jars

# Build stage for pip packages
FROM python:3.12-slim-bookworm AS python_packages

RUN pip debug --verbose

RUN apt-get update && \
    apt-get install -y git && \
    pip install pipenv

# Essential updates for build to succeed on arm64:
RUN apt update && \
    apt install -y build-essential

RUN python --version && \
    python -m pip install --upgrade --no-cache-dir pip && \
    python -m pip install --no-cache-dir wheel && \
    python -m pip install --no-cache-dir pipenv && \
    python -m pip install setuptools>=72.1.0 packaging>=24.1  && \
    python -m pip install --no-cache-dir python-crfsuite==0.9.10  # does not have an aarch64 wheel

ENV PYTHONPATH=/helix.spark
ENV PYTHONPATH="/opt/project:${PYTHONPATH}"

RUN pip list -v

# Run stage
FROM spark:3.5.1-java17-python3
USER root

ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETVARIANT

## install AWS S3 library (this can be removed after testing the above mvn downloads are working correctluy)
#RUN apt-get install -y curl && \
#    rm -f /opt/spark/jars/hadoop-aws-2.7.3.jar && \
#    curl https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.944/aws-java-sdk-bundle-1.11.944.jar -o /opt/spark/jars/aws-java-sdk-bundle-1.11.944.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.2.0/hadoop-aws-3.2.0.jar -o /opt/spark/jars/hadoop-aws-3.2.0.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.1.1/spark-sql-kafka-0-10_2.12-3.1.1.jar -o /opt/spark/jars/spark-sql-kafka-0-10_2.12-3.1.1.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/2.6.0/kafka-clients-2.6.0.jar -o /opt/spark/jars/kafka-clients-2.6.0.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/3.1.1/spark-token-provider-kafka-0-10_2.12-3.1.1.jar -o /opt/spark/jars/spark-token-provider-kafka-0-10_2.12-3.1.1.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.6.2/commons-pool2-2.6.2.jar -o /opt/spark/jars/commons-pool2-2.6.2.jar

RUN apt-get update

# install system packages
RUN /usr/bin/python3 --version && \
    /usr/bin/python3 -m pip install --upgrade --no-cache-dir pip && \
    /usr/bin/python3 -m pip install --no-cache-dir wheel && \
    /usr/bin/python3 -m pip install --no-cache-dir pre-commit && \
    /usr/bin/python3 -m pip install --no-cache-dir pipenv

ENV PYTHONPATH=/helix.spark
ENV PYTHONPATH="/opt/project:${PYTHONPATH}"
ENV CLASSPATH=/helix.spark/jars:$CLASSPATH

COPY --from=build /tmp/spark/jars /opt/spark/jars

RUN mkdir -p /usr/local/lib/python3.12/site-packages/ && \
    mkdir -p /usr/local/lib/python3.12/dist-packages

# in debian, the python packages are installed in dist-packages
# https://stackoverflow.com/questions/9387928/whats-the-difference-between-dist-packages-and-site-packages
COPY --from=python_packages /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/dist-packages/

RUN ls -halt /opt/spark/jars/

#COPY ./jars/* /opt/spark/jars/
COPY ./conf/* /opt/spark/conf/

RUN ls -halt /opt/spark/jars/

COPY ./test.py ./

# ENV SPARK_EXTRA_CLASSPATH

ENV AWS_DEFAULT_REGION=us-east-1
ENV AWS_REGION=us-east-1

ENV HADOOP_CONF_DIR=/opt/spark/conf

#RUN apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/

#RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

COPY minimal_entrypoint.sh /opt/minimal_entrypoint.sh
COPY pom.xml /opt/pom.xml

RUN chmod a+x /opt/minimal_entrypoint.sh

USER root
# install python 3.12 - it's not available in normal ubuntu repositories
# https://github.com/deadsnakes/issues/issues/53
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F23C5A6CF475977595C89F51BA6932366A755776 && \
    echo "deb https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu/ jammy main" | tee /etc/apt/sources.list.d/deadsnakes-ubuntu-ppa-lunar.list && \
    apt-get update && apt-get install -y python3.12 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

RUN apt-get clean

# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope

RUN echo "I'm building for platform=$TARGETPLATFORM, architecture=$TARGETARCH, variant=$TARGETVARIANT"

# this command below fails in Github Runner
RUN if [ "$TARGETARCH" = "amd64" ] ; then /opt/spark/bin/spark-submit --master local[*] test.py; fi


# Run as non-root user
# https://spark.apache.org/docs/latest/running-on-kubernetes.html#user-identity
USER 185
