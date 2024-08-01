FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y git && \
    pip install pipenv

# Essential updates for build to succeed on arm64:
RUN apt install -y build-essential
RUN pip install --upgrade setuptools

COPY Pipfile* ./

RUN pipenv lock --dev && \
    pipenv sync --dev --system --verbose

WORKDIR /sourcecode

RUN apt-get clean

CMD ["pre-commit", "run", "--all-files"]
