# Build stage
FROM maven:3.6.3-openjdk-15-slim AS build
# get dependencies for bsights-engine-spark
RUN mkdir /tmp/bsights-engine-spark \
    && cd /tmp/bsights-engine-spark \
    && curl https://raw.githubusercontent.com/icanbwell/bsights-engine-spark/main/pom.xml -o pom.xml \
    && mkdir /tmp/spark \
    && mkdir /tmp/spark/jars \
    && mvn dependency:copy-dependencies -DoutputDirectory=/tmp/spark/jars -Dhttps.protocols=TLSv1.2 \
    && ls /tmp/spark/jars \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.2:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=com.amazonaws:aws-java-sdk-bundle:1.12.128 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.2:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.hadoop:hadoop-aws:3.2.0 \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:3.1.2:copy -DoutputDirectory=/tmp/spark/jars -DrepoUrl=https://download.java.net/maven/2/ -Dartifact=org.apache.spark:spark-sql-kafka-0-10_2.12:3.1.1 \
    && ls /tmp/spark/jars

# Run stage
FROM imranq2/spark-py:java15-3.0.28

USER root

## install AWS S3 library (this can be removed after testing the above mvn downloads are working correctluy)
#RUN apt-get install -y curl && \
#    rm -f /opt/spark/jars/hadoop-aws-2.7.3.jar && \
#    curl https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.944/aws-java-sdk-bundle-1.11.944.jar -o /opt/spark/jars/aws-java-sdk-bundle-1.11.944.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.2.0/hadoop-aws-3.2.0.jar -o /opt/spark/jars/hadoop-aws-3.2.0.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.1.1/spark-sql-kafka-0-10_2.12-3.1.1.jar -o /opt/spark/jars/spark-sql-kafka-0-10_2.12-3.1.1.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/2.6.0/kafka-clients-2.6.0.jar -o /opt/spark/jars/kafka-clients-2.6.0.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/3.1.1/spark-token-provider-kafka-0-10_2.12-3.1.1.jar -o /opt/spark/jars/spark-token-provider-kafka-0-10_2.12-3.1.1.jar && \
#    curl https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.6.2/commons-pool2-2.6.2.jar -o /opt/spark/jars/commons-pool2-2.6.2.jar

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

RUN pipenv sync --system  # This should not be needed because the line below covers system also
RUN pipenv sync --dev --system

COPY --from=build /tmp/spark/jars /opt/spark/jars

RUN ls -halt /opt/spark/jars/

#COPY ./jars/* /opt/spark/jars/
COPY ./conf/* /opt/spark/conf/

RUN ls -halt /opt/spark/jars/

COPY ./test.py ./

# ENV SPARK_EXTRA_CLASSPATH

ENV AWS_DEFAULT_REGION=us-east-1
ENV AWS_REGION=us-east-1

ENV HADOOP_CONF_DIR=/opt/spark/conf

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

RUN apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/

RUN /opt/spark/bin/spark-submit --master local[*] test.py

USER root
