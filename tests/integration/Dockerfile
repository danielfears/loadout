FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates \
        git \
        sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash loadout \
    && printf 'loadout ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/loadout \
    && chmod 0440 /etc/sudoers.d/loadout

COPY --chown=loadout:loadout . /home/loadout/loadout

USER loadout
WORKDIR /home/loadout/loadout
ENV PATH="/home/loadout/.local/bin:${PATH}"
ENV LOADOUT_CONTAINER=1

RUN ./bootstrap.sh \
        --skip-windows \
        --skip-services

RUN loadout check \
        --skip-windows \
        --skip-services \
    && loadout apply \
        --skip-windows \
        --skip-services \
        --yes
