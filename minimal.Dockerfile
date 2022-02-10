ARG JRE_VERSION=15-slim

# Build stage for maven packages
FROM maven:3.6.3-openjdk-15-slim AS build

# Define default aws sdk jar version
ARG AWS_SDK_BUNDLE_VERSION_DEFAULT=1.12.128
# Define default aws sdk jar version
ARG KAFKA_VERSION=spark-sql-kafka-0-10_2.12:3.1.1
## Define default aws sdk jar version
#ARG AWS_SDK_BUNDLE_VERSION_DEFAULT=1.12.128

# get dependencies for bsights-engine-spark
RUN mkdir /tmp/bsights-engine-spark \
    && cd /tmp/bsights-engine-spark \
    && curl https://raw.githubusercontent.com/icanbwell/bsights-engine-spark/main/pom.xml -o pom.xml \
    && mkdir /tmp/spark \
    && mkdir /tmp/spark/jars \
    && mvn dependency:copy-dependencies -DoutputDirectory=/tmp/spark/jars -Dhttps.protocols=TLSv1.2 \
    && ls /tmp/spark/jars \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.2:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.amazonaws:aws-java-sdk-bundle:${AWS_SDK_BUNDLE_VERSION_DEFAULT} \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.2:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.hadoop:hadoop-aws:3.2.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.2:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:${KAFKA_VERSION} \
    && ls /tmp/spark/jars

# Build stage for pip packages
FROM python:3.7 as python_packages

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
ENV PYTHONPATH "/opt/project:${PYTHONPATH}"

COPY Pipfile* /helix.pipelines/
WORKDIR /helix.pipelines

RUN pipenv sync --system --verbose # This should not be needed because the line below covers system also
#RUN pipenv sync --dev --system --verbose

RUN pip list -v

FROM openjdk:${JRE_VERSION} AS base

# Define default Spark version
ARG SPARK_VERSION_DEFAULT=3.1.1
# Define default Hadoop version
ARG HADOOP_VERSION_DEFAULT=3.2
# Define default Hadoop aws jar version
ARG HADOOP_AWS_VERSION_DEFAULT=3.2.0

# Define ENV variables
ENV SPARK_VERSION=${SPARK_VERSION_DEFAULT}
ENV HADOOP_VERSION=${HADOOP_VERSION_DEFAULT}
ENV HADOOP_AWS_VERSION=${HADOOP_AWS_VERSION_DEFAULT}
ENV AWS_SDK_BUNDLE_VERSION=${AWS_SDK_BUNDLE_VERSION_DEFAULT}
ENV GCS_CONNECTOR_VERSION=${GCS_CONNECTOR_VERSION_DEFAULT}

RUN apt-get update \
    && apt-get install -y bash tini libc6 libpam-modules krb5-user libnss3 procps curl

FROM base AS spark-base

# Download and extract Spark
RUN curl -L https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz -o spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && tar -xvzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

COPY entrypoint.sh /opt/
COPY decom.sh /opt/

RUN chmod a+x /opt/entrypoint.sh
RUN chmod a+x /opt/decom.sh

FROM spark-base AS sparkbuilder

# Set SPARK_HOME
ENV SPARK_HOME=/opt/spark

# Extend PATH environment variable
ENV PATH=${PATH}:${SPARK_HOME}/bin

# Create the application directory
RUN mkdir -p /app

#FROM sparkbuilder AS spark-with-s3-gcs
#
## Download S3 and GCS jars
#RUN curl -L https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar -o ${SPARK_HOME}/jars/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
#    && curl -L https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_BUNDLE_VERSION}/aws-java-sdk-bundle-${AWS_SDK_BUNDLE_VERSION}.jar -o ${SPARK_HOME}/jars/aws-java-sdk-bundle-${AWS_SDK_BUNDLE_VERSION}.jar
#
FROM sparkbuilder AS spark-with-jar

ARG spark_uid=185

ENV PYTHONPATH=/helix.pipelines
ENV PYTHONPATH=$SPARK_HOME/python/:$PYTHONPATH
ENV PYTHONPATH "/opt/project:${PYTHONPATH}"
ENV CLASSPATH=/helix.pipelines/jars:$CLASSPATH

#RUN apt-get update -y \
#    && apt-get install -y python3 python3-pip \
#    && pip3 install --upgrade pip setuptools \
#    # Removed the .cache to save space
#    && rm -r /root/.cache && rm -rf /var/cache/apt/*

RUN set -ex && \
    sed -i 's/http:\/\/deb.\(.*\)/https:\/\/deb.\1/g' /etc/apt/sources.list && \
    apt-get update && \
    ln -s /lib /lib64 && \
    apt install -y bash tini libc6 libpam-modules krb5-user libnss3 procps && \
    apt-get install -y python3 python3-pip && \
    pip3 install --upgrade pip setuptools && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    rm -rf /var/cache/apt/*

COPY Pipfile* /helix.pipelines/
WORKDIR /helix.pipelines

COPY --from=build /tmp/spark/jars /opt/spark/jars

RUN mkdir -p /usr/local/lib/python3.7/site-packages/ && \
    mkdir -p /usr/local/lib/python3.7/dist-packages
COPY --from=python_packages /usr/local/lib/python3.7/site-packages/ /usr/local/lib/python3.7/site-packages/
#COPY --from=python_packages /usr/local/lib/python3.7/dist-packages/ /usr/local/lib/python3.7/dist-packages/

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

#RUN python -v
RUN python3 -v

RUN /opt/spark/bin/spark-submit --master local[*] test.py

ENTRYPOINT [ "/opt/entrypoint.sh" ]

# Specify the User that the actual main process will run as
USER ${spark_uid}
