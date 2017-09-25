FROM phusion/baseimage

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# required packages
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    bash \
    bash-completion \
    curl \
    dnsutils \
    vim && \
    apt-get clean

ENV MONGOOSEICE_UDP_BIND_IP=0.0.0.0 MONGOOSEICE_UDP_PORT=3478 MIX_ENV=prod \
    MONGOOSEICE_TCP_BIND_IP=0.0.0.0 MONGOOSEICE_TCP_PORT=3479 MIX_ENV=prod \
    REPLACE_OS_VARS=true SHELL=/bin/bash

WORKDIR /opt/app

ADD mongooseice.tar.gz ./
ADD docker/start.sh /opt/app/start.sh
RUN chmod +x /opt/app/start.sh

# Move priv dir
RUN mv $(find lib -name mongooseice-*)/priv .
RUN ln -s $(pwd)/priv $(find lib -name mongooseice-*)/priv

VOLUME /opt/app/priv

CMD ["foreground"]
ENTRYPOINT ["/opt/app/start.sh"]
