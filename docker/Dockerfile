FROM debian:stretch as builder

ARG ERLANG_VERSION=22.0
ARG ELIXIR_VERSION=1.9
ARG MIX_ENV=prod

ENV ERLANG_VERSION ${ERLANG_VERSION}
ENV ELIXIR_VERSION ${ELIXIR_VERSION}
ENV MIX_ENV ${MIX_ENV}

SHELL ["/bin/bash", "-c"]

# Handle locales
RUN apt-get update && \
        apt-get install --yes locales && \
        sed -i '/^#.* en_US.UTF-8 /s/^#//' /etc/locale.gen && \
        locale-gen

ENV LANG="en_US.UTF-8" LANGUAGE="en_US:en"

# Install build utils
RUN apt-get install --yes \
        wget \
        unzip \
        build-essential \
        apt-transport-https \
        git

# Install Erlang & Elixir
RUN echo "deb https://packages.erlang-solutions.com/debian stretch contrib" >> /etc/apt/sources.list && \
        cat /etc/apt/sources.list && \
        wget --quiet -O - https://packages.erlang-solutions.com/debian/erlang_solutions.asc | apt-key add - && \
        apt-get update && \
        export EXACT_ERLANG_VERSION=`apt-cache madison esl-erlang | awk '{print \$3;}' | grep ${ERLANG_VERSION} | head -1` && \
        export EXACT_ELIXIR_VERSION=`apt-cache madison elixir | awk '{print \$3;}' | grep ${ELIXIR_VERSION} | head -1` && \
        apt-get install --yes \
        esl-erlang=$EXACT_ERLANG_VERSION \
        elixir=$EXACT_ELIXIR_VERSION

WORKDIR /build

COPY mix.exs mix.lock ./

RUN mix local.hex --force && \
        mix local.rebar --force && \
        mix deps.get && \
        mix deps.compile

COPY config config/
COPY lib lib/
COPY rel rel/
COPY priv priv/

RUN mix compile && \
        mix distillery.release --no-tar && \
        mkdir /release && \
        cp -r _build/prod/rel/mongooseice/* /release/


FROM debian:stretch-slim

ENV MONGOOSEICE_UDP_BIND_IP=0.0.0.0 MONGOOSEICE_UDP_PORT=3478 MIX_ENV=prod \
    MONGOOSEICE_TCP_BIND_IP=0.0.0.0 MONGOOSEICE_TCP_PORT=3479 MIX_ENV=prod \
    REPLACE_OS_VARS=true SHELL=/bin/bash
ENV HOME /app

# Handle locales
RUN apt-get update && \
        apt-get install --yes locales && \
        sed -i '/^#.* en_US.UTF-8 /s/^#//' /etc/locale.gen && \
        locale-gen
ENV LANG="en_US.UTF-8" LANGUAGE="en_US:en"

# libcrypto.so is required by ERTS. curl for healthcheck.
RUN apt-get install --yes \
        libssl1.1

WORKDIR /app

COPY --from=builder /release/ .
COPY docker/start.sh /app/start.sh

RUN groupadd -r app && useradd -r -g app app
RUN chown -R app /app
USER app

ENTRYPOINT [ "/app/start.sh" ]
CMD [ "foreground" ]