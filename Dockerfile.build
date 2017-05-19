FROM phusion/baseimage

ENV HOME=/opt/app/ TERM=xterm
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install Elixir and basic build dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    gcc \
    g++ \
    make \
    wget && \
    wget http://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && \
    dpkg -i erlang-solutions_1.0_all.deb && \
    apt-get update && \
    apt-get install -y esl-erlang elixir && \
    apt-get clean


# Install Hex+Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /opt/app

ENV MIX_ENV=prod

# Cache elixir deps
COPY mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

COPY . .

RUN mix release --env=prod --verbose
