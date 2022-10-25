# Build stage for maven packages
FROM maven:3.8.6-eclipse-temurin-17-focal AS build
# get dependencies for bsights-engine-spark
RUN mkdir /tmp/bsights-engine-spark \
    && cd /tmp/bsights-engine-spark \
#    && curl https://raw.githubusercontent.com/icanbwell/bsights-engine-spark/main/pom.xml -o pom.xml \
    && mkdir /tmp/spark \
    && mkdir /tmp/spark/jars \
#    && mvn dependency:copy-dependencies -DoutputDirectory=/tmp/spark/jars -Dhttps.protocols=TLSv1.2 \
    && ls /tmp/spark/jars \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.amazonaws:aws-java-sdk-bundle:1.12.128 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.hadoop:hadoop-aws:3.2.2 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:spark-sql-kafka-0-10_2.12:3.3.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.3.0:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=io.delta:delta-core_2.12:2.1.0 \
    && ls /tmp/spark/jars

# Build stage for pip packages
FROM python:3.9 as python_packages

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

#ENV PIP_ONLY_BINARY=:all:
#ENV PIP_NO_BINARY=autoflake
#ENV PIP_USE_WHEEL=1

RUN pip debug --verbose

#RUN export PIP_ONLY_BINARY=:all: && \
#    export PIP_NO_BINARY="autoflake" && \
#    PIP_NO_BINARY=autoflake pipenv lock --dev

RUN pipenv lock --dev && \
    pipenv sync --dev --system --verbose

RUN pip list -v

# Run stage
FROM imranq2/spark:java17-3.3.0.9
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

# These are the versions compatible for DBR 11.x
ARG python_version="3.9"
ARG pip_version="21.2.4"
ARG setuptools_version="58.0.4"
ARG wheel_version="0.37.0"
ARG virtualenv_version="20.8.0"

# Installs python 3.8 and virtualenv for Spark and Notebooks
RUN apt-get update \
  && apt-get install curl software-properties-common -y \
  && add-apt-repository -y ppa:deadsnakes/ppa \
  && apt-get remove -y 'python3.*' \
  && apt-get install -y python${python_version} python${python_version}-distutils \
  && curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
  && /usr/bin/python${python_version} get-pip.py pip==${pip_version} setuptools==${setuptools_version} wheel==${wheel_version} \
  && rm get-pip.py

# install system packages
RUN /usr/bin/python${python_version} --version && \
    /usr/bin/python${python_version} -m pip install --upgrade --no-cache-dir pip && \
    /usr/bin/python${python_version} -m pip install --no-cache-dir wheel && \
    /usr/bin/python${python_version} -m pip install --no-cache-dir pre-commit && \
    /usr/bin/python${python_version} -m pip install --no-cache-dir pipenv && \
    /usr/bin/python${python_version} -m pip install --no-cache-dir pyspark==3.3.0

ENV PYTHONPATH=/helix.pipelines
ENV PYTHONPATH=/opt/project:${PYTHONPATH}
ENV CLASSPATH=/helix.pipelines/jars:$CLASSPATH

COPY Pipfile* /helix.pipelines/
WORKDIR /helix.pipelines

COPY --from=build /tmp/spark/jars /opt/spark/jars

RUN mkdir -p /usr/local/lib/python${python_version}/site-packages/ && \
    mkdir -p /usr/local/lib/python${python_version}/dist-packages

COPY --from=python_packages /usr/local/lib/python${python_version}/site-packages/ /usr/local/lib/python${python_version}/site-packages/
COPY --from=python_packages /usr/local/lib/python${python_version}/dist-packages/ /usr/local/lib/python${python_version}/dist-packages/
# get the shell commands for these packages also
COPY --from=python_packages /usr/local/bin/pytest /usr/local/bin/pytest
COPY --from=python_packages /helix.pipelines/Pipfile* /helix.pipelines/

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

#RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1

COPY minimal_entrypoint.sh /opt/minimal_entrypoint.sh

RUN chmod a+x /opt/minimal_entrypoint.sh

USER root
RUN update-alternatives --install /usr/bin/python python /usr/bin/python${python_version} 1
RUN update-alternatives --install /usr/bin/python3 python /usr/bin/python${python_version} 1

# https://docs.docker.com/engine/reference/builder/#automatic-platform-args-in-the-global-scope

RUN echo "I'm building for platform=$TARGETPLATFORM, architecture=$TARGETARCH, variant=$TARGETVARIANT"
# this command below fails in Github Runner
RUN if [ "$TARGETARCH" = "amd64" ] ; then /opt/spark/bin/spark-submit --master local[*] test.py; fi
