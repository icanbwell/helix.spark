FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y git && \
    pip install pipenv

# Essential updates for build to succeed on arm64:
RUN apt update && \
    apt install -y build-essential \

RUN python --version && \
    python -m pip install --upgrade --no-cache-dir pip && \
    python -m pip install --no-cache-dir wheel && \
    python -m pip install --no-cache-dir pipenv && \
    python -m pip install setuptools>=72.1.0 packaging>=24.1 \

COPY Pipfile* ./

RUN pipenv lock --dev && \
    pipenv sync --dev --system --verbose

WORKDIR /sourcecode

RUN apt-get clean

CMD ["pre-commit", "run", "--all-files"]
