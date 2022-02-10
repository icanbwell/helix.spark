ARG JRE_VERSION=15-slim
FROM openjdk:${JRE_VERSION} AS base

# Define default Spark version
ARG SPARK_VERSION_DEFAULT=3.1.1
# Define default Hadoop version
ARG HADOOP_VERSION_DEFAULT=3.2
# Define default Hadoop aws jar version
ARG HADOOP_AWS_VERSION_DEFAULT=3.2.0
# Define default aws sdk jar version
ARG AWS_SDK_BUNDLE_VERSION_DEFAULT=1.11.375
# Define default GCS connector jar version
ARG GCS_CONNECTOR_VERSION_DEFAULT=hadoop3-2.2.0

# Define ENV variables
ENV SPARK_VERSION=${SPARK_VERSION_DEFAULT}
ENV HADOOP_VERSION=${HADOOP_VERSION_DEFAULT}
ENV HADOOP_AWS_VERSION=${HADOOP_AWS_VERSION_DEFAULT}
ENV AWS_SDK_BUNDLE_VERSION=${AWS_SDK_BUNDLE_VERSION_DEFAULT}
ENV GCS_CONNECTOR_VERSION=${GCS_CONNECTOR_VERSION_DEFAULT}

RUN apt-get update \
    && apt-get install -y bash tini libc6 libpam-modules krb5-user libnss3 procps

FROM base AS spark-base

# Download and extract Spark
RUN curl -L https://downloads.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz -o spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && tar -xvzf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz

COPY entrypoint.sh /opt/spark

RUN chmod a+x /opt/spark/entrypoint.sh

FROM spark-base AS sparkbuilder

# Set SPARK_HOME
ENV SPARK_HOME=/opt/spark

# Extend PATH environment variable
ENV PATH=${PATH}:${SPARK_HOME}/bin

# Create the application directory
RUN mkdir -p /app

FROM sparkbuilder AS spark-with-s3-gcs

# Download S3 and GCS jars
RUN curl -L https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar -o ${SPARK_HOME}/jars/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
    && curl -L https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_BUNDLE_VERSION}/aws-java-sdk-bundle-${AWS_SDK_BUNDLE_VERSION}.jar -o ${SPARK_HOME}/jars/aws-java-sdk-bundle-${AWS_SDK_BUNDLE_VERSION}.jar

FROM spark-with-s3-gcs AS spark-with-jar

WORKDIR /app
# Add application jar in /app
# ADD your-app.jar /app
USER root

ENTRYPOINT [ "/opt/spark/entrypoint.sh" ]
