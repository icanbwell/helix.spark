FROM python:3.10-slim

RUN apt-get update && \
    apt-get install -y git && \
    pip install pipenv

# Essential updates for build to succeed on arm64:
RUN apt install -y build-essential

COPY Pipfile* ./

RUN pipenv lock --dev && \
    pipenv sync --dev --system --verbose

WORKDIR /sourcecode

RUN apt-get clean

CMD ["pre-commit", "run", "--all-files"]
