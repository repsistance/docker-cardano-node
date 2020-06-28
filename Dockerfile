ARG CARDANO_NODE_COMMIT=master

# misc
## Dockerfile.src
#FROM repsistance/cardano-node:src-${CARDANO_NODE_COMMIT} AS src
## Dockerfile.src-build
#FROM repsistance/cardano-node:src-build-${CARDANO_NODE_COMMIT} AS src-build
## Dockerfile.src-build-nixos
FROM repsistance/cardano-node:src-build-nixos-${CARDANO_NODE_COMMIT} AS src-build-nixos
## Dockerfile.bin-build
#FROM repsistance/cardano-node:bin-build-${CARDANO_NODE_COMMIT} AS bin-build
## nixos assets
#FROM nixos/nix AS github-nix-assets
#RUN nix-env -iA nixpkgs.curl
#RUN curl -s https://raw.githubusercontent.com/input-output-hk/cardano-ops/master/topologies/ff-peers.nix \
#      | nix-instantiate --eval --json - > /var/tmp/ff-peers.json

# production base
FROM ubuntu:20.04 AS base
ENV APT_ARGS="-y -o APT::Install-Suggests=false -o APT::Install-Recommends=false"
ARG BASE_PACKAGES="git bash jq libatomic1 sudo curl screen python3-pip netbase net-tools dnsutils bc systemd gpg gpg-agent"
ENV BASE_PACKAGES ${BASE_PACKAGES}
ENV GUILD_OPS_BRANCH master
ENV GUILD_OPS_GIT_REPO https://github.com/cardano-community/guild-operators.git
ENV GUILD_OPS_HOME /opt/cardano/guild-operators

VOLUME ["/opt/cardano/cnode/logs", "/opt/cardano/cnode/db", "/opt/cardano/cnode/priv"]
ENV CNODE_HOME /opt/cardano/cnode
ENV CARDANO_NODE_SOCKET_PATH /opt/cardano/cnode/sockets/node0.socket
RUN mkdir -p /nonexistent /data && \
    chown nobody: /nonexistent && \
    mkdir -p ${CNODE_HOME} && \
    chown -R nobody: ${CNODE_HOME}/..
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install ${APT_ARGS} ${BASE_PACKAGES} ${BUILD_PACKAGES} && \
    pip3 install yq && \
    git clone --single-branch --branch ${GUILD_OPS_BRANCH} ${GUILD_OPS_GIT_REPO} ${GUILD_OPS_HOME} && \
    ln -s ${GUILD_OPS_HOME}/scripts/cnode-helper-scripts/cntools.sh /usr/local/bin/cntools && \
    chmpod +x /usr/local/bin/cntools

COPY --from=src-build-nixos /output/*/bin/cardano* /usr/local/bin/
USER nobody
RUN curl -sSL https://raw.githubusercontent.com/rcmorano/baids/master/baids | bash -s install
COPY baids/* /nonexistent/.baids/functions.d/
COPY ./assets /assets
USER nobody
## standalone images (no genesis/topology prefetched)
FROM base AS standalone-tn-base
ENV NETWORK=standalone-tn
RUN bash -c 'source /nonexistent/.baids/baids && ${NETWORK}-setup'
#COPY --from=github-nix-assets /var/tmp/ff-peers.json /opt/cardano/cnode/files/ff-peers.json
CMD ["bash", "-c", "chown -R nobody: ${CNODE_HOME} && sudo -EHu nobody bash -c 'source ~/.baids/baids && ${NETWORK}-cnode-run-as-${CNODE_ROLE}'"]
FROM standalone-tn-base AS standalone-tn-passive
ENV CNODE_ROLE=passive
FROM standalone-tn-base AS standalone-tn-leader
ENV CNODE_ROLE=leader
## guild-ops images
FROM base AS guild-ops-ptn0-base
ENV NETWORK=guild-ops-ptn0
RUN bash -c 'source /nonexistent/.baids/baids && ${NETWORK}-setup'
USER root
CMD ["bash", "-c", "chown -R nobody: ${CNODE_HOME} && sudo -EHu nobody bash -c 'source ~/.baids/baids && ${NETWORK}-cnode-run-as-${CNODE_ROLE}'"]
FROM guild-ops-ptn0-base AS guild-ops-ptn0-passive
ENV CNODE_ROLE=passive
FROM guild-ops-ptn0-base AS guild-ops-ptn0-leader
ENV CNODE_ROLE=leader
## iohk images
FROM base AS iohk-stn-base
ENV NETWORK=iohk-stn
RUN bash -c 'source /nonexistent/.baids/baids && ${NETWORK}-setup'
USER root
CMD ["bash", "-c", "chown -R nobody: ${CNODE_HOME} && sudo -EHu nobody bash -c 'source ~/.baids/baids && ${NETWORK}-cnode-run-as-${CNODE_ROLE}'"]
FROM iohk-stn-base AS iohk-stn-passive
ENV CNODE_ROLE=passive
FROM iohk-stn-base AS iohk-stn-leader
ENV CNODE_ROLE=leader

## distroless poc
FROM gcr.io/distroless/base AS barebone-node
COPY --from=src-build-nixos /output/*/bin/cardano* /usr/local/bin/
CMD ["/usr/local/bin/cardano-node"]

