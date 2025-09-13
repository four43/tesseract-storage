# syntax=docker/dockerfile:1
FROM python:3.13-slim-trixie

WORKDIR /app
ARG INSTALL_DEV_DEPS=1

COPY util ./util
COPY pyproject.toml requirements.lock.* ./

RUN --mount=type=cache,target=/root/.cache/pip \
    if [ "$INSTALL_DEV_DEPS" = "1" ]; then \
        INSTALL_TYPE="dev"; \
    else \
        INSTALL_TYPE=""; \
    fi && \
        ./util/install-dependencies "$INSTALL_TYPE"

COPY ./ ./

# For our "Lambda-Everywhere" pattern
ENTRYPOINT [ "/lambda-entrypoint.sh" ]
CMD [ "tesseract.__main__.lambda_handler" ]
