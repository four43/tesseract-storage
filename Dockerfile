# syntax=docker/dockerfile:1
FROM aerisweather/lambda:python3.12-custom

WORKDIR /app
ARG INSTALL_DEV_DEPS=1

COPY util ./util
COPY pyproject.toml requirements.lock.* ./

RUN --mount=type=ssh \
    --mount=type=cache,target=/root/.cache/pip \
    --mount=type=secret,id=github_token,target=/run/secrets/github_token \
    export GITHUB_TOKEN=$(cat /run/secrets/github_token); \
    if [ "$INSTALL_DEV_DEPS" = "1" ]; then \
        INSTALL_TYPE="dev"; \
    else \
        INSTALL_TYPE=""; \
    fi && \
        ./util/install-dependencies "$INSTALL_TYPE"

COPY ./ ./

# For our "Lambda-Everywhere" pattern
ENTRYPOINT [ "/lambda-entrypoint.sh" ]
CMD [ "{MODULE_NAME}.__main__.lambda_handler" ]
