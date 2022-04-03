FROM python:3.7-slim

RUN apt-get update && \
    apt-get install -y git && \
    pip install pipenv

# Essential updates for build to succeed on arm64:
RUN apt install -y build-essential

WORKDIR /sourcecode

RUN apt-get clean
