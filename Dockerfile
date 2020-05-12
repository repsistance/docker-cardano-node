FROM ubuntu:20.04 AS build-env

ARG CABAL_TARGETS="cardano-node cardano-cli"
ENV CNODE_HOME /opt/cardano-node
WORKDIR ${CNODE_HOME}

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl gnupg build-essential pkg-config ghc cabal-install git libffi-dev libgmp-dev libssl-dev libtinfo-dev libsystemd-dev zlib1g-dev

ARG CARDANO_NODE_COMMIT=master
ENV CARDANO_NODE_COMMIT ${CARDANO_NODE_COMMIT}
RUN git clone https://github.com/input-output-hk/cardano-node ${CNODE_HOME} && \
    git checkout ${CARDANO_NODE_COMMIT} && \
    cabal update && \
    for target in ${CABAL_TARGETS}; do cabal new-build ${target}; done

# TODO: there is probably a better way to extract/install binaries
RUN mkdir /output && \
    find dist-newstyle/build -type f -executable | grep -v ".so$" | while read bin; \
    do \
      cp -a ${PWD}/$bin /output; \
    done

# production base
FROM ubuntu:20.04 AS base
ARG BASE_PACKAGES="bash jq libatomic1 sudo curl screen"
ENV BASE_PACKAGES ${BASE_PACKAGES}
ARG BUILD_PACKAGES="git"
ENV BUILD_PACKAGES ${BUILD_PACKAGES}
VOLUME ["/opt/cardano/cnode/logs", "/opt/cardano/cnode/db", "/opt/cardano/cnode/priv"]
ENV CNODE_HOME /opt/cardano/cnode
RUN mkdir -p /nonexistent /data && \
    chown nobody: /nonexistent && \
    mkdir -p ${CNODE_HOME} && \
    chown -R nobody: ${CNODE_HOME}
RUN apt-get update -qq && apt-get install -y ${BASE_PACKAGES} ${BUILD_PACKAGES}
COPY --from=build-env /output/cardano* /usr/local/bin/
USER nobody
RUN curl -sSL https://raw.githubusercontent.com/rcmorano/baids/master/baids | bash -s install
COPY baids/* /nonexistent/.baids/functions.d/
## guild-ops images
FROM base AS guild-ops-ptn0-base
ENV NETWORK=guild-ops-ptn0
RUN bash -c 'source /nonexistent/.baids/baids && ${NETWORK}-setup'
USER root
RUN apt-get remove -y ${BUILD_PACKAGES} && apt-get autoremove -y && apt-get clean -y
CMD ["bash", "-c", "chown -R nobody: ${CNODE_HOME} && sudo -EHu nobody bash -c 'source ~/.baids/baids && ${NETWORK}-cnode-run-as-${CNODE_ROLE}'"]
FROM guild-ops-ptn0-base AS guild-ops-ptn0-passive
ENV CNODE_ROLE=passive
FROM guild-ops-ptn0-base AS guild-ops-ptn0-leader
ENV CNODE_ROLE=leader
## iohk images
FROM base AS iohk-fftn-base
ENV NETWORK=iohk-fftn
RUN bash -c 'source /nonexistent/.baids/baids && ${NETWORK}-setup'
USER root
RUN apt-get remove -y ${BUILD_PACKAGES} && apt-get autoremove -y && apt-get clean -y
CMD ["bash", "-c", "chown -R nobody: ${CNODE_HOME} && sudo -EHu nobody bash -c 'source ~/.baids/baids && ${NETWORK}-cnode-run-as-${CNODE_ROLE}'"]
FROM iohk-fftn-base AS iohk-fftn-passive
ENV CNODE_ROLE=passive
FROM iohk-fftn-base AS iohk-fftn-leader
ENV CNODE_ROLE=leader

FROM gcr.io/distroless/base AS barebone-node
COPY --from=build-env /output/cardano* /usr/local/bin/
CMD ["/usr/local/bin/cardano-node"]
