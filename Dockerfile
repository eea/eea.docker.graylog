ARG JAVA_VERSION_MAJOR=8

# layer for download and verifying
FROM graylog/graylog:4.3.12 as graylog-downloader


# -------------------------------------------------------------------------------------------------
#
# final layer
FROM eclipse-temurin:${JAVA_VERSION_MAJOR}-jre-focal

ARG VCS_REF
ARG GRAYLOG_VERSION
ARG BUILD_DATE
ARG GRAYLOG_HOME=/usr/share/graylog
ARG GRAYLOG_USER=graylog
ARG GRAYLOG_UID=1100
ARG GRAYLOG_GROUP=graylog
ARG GRAYLOG_GID=1100
ARG JAVA_VERSION_MAJOR

COPY --chown=${GRAYLOG_UID}:${GRAYLOG_GID} --from=graylog-downloader ${GRAYLOG_HOME} ${GRAYLOG_HOME}

COPY --chown=${GRAYLOG_UID}:${GRAYLOG_GID} --from=graylog-downloader /docker-entrypoint.sh /
COPY --chown=${GRAYLOG_UID}:${GRAYLOG_GID} --from=graylog-downloader /health_check.sh /



WORKDIR ${GRAYLOG_HOME}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# hadolint ignore=DL3027,DL3008,DL3005
RUN \
  echo "export BUILD_DATE=${BUILD_DATE}"           >> /etc/profile.d/graylog.sh && \
  echo "export GRAYLOG_VERSION=${GRAYLOG_VERSION}" >> /etc/profile.d/graylog.sh && \
  echo "export GRAYLOG_SERVER_JAVA_OPTS='-Dlog4j2.formatMsgNoLookups=true -Djdk.tls.acknowledgeCloseNotify=true -XX:+UnlockExperimentalVMOptions -XX:NewRatio=1 -XX:MaxMetaspaceSize=256m -server -XX:+ResizeTLAB -XX:-OmitStackTraceInFastThrow'" >> /etc/profile.d/graylog.sh && \
  echo "export GRAYLOG_HOME=${GRAYLOG_HOME}"       >> /etc/profile.d/graylog.sh && \
  echo "export GRAYLOG_USER=${GRAYLOG_USER}"       >> /etc/profile.d/graylog.sh && \
  echo "export GRAYLOG_GROUP=${GRAYLOG_GROUP}"     >> /etc/profile.d/graylog.sh && \
  echo "export GRAYLOG_UID=${GRAYLOG_UID}"         >> /etc/profile.d/graylog.sh && \
  echo "export GRAYLOG_GID=${GRAYLOG_GID}"         >> /etc/profile.d/graylog.sh && \
  echo "export PATH=${GRAYLOG_HOME}/bin:${PATH}"   >> /etc/profile.d/graylog.sh && \
  apt-get update  > /dev/null && \
  apt-get upgrade -y > /dev/null && \
  apt-get install --no-install-recommends --assume-yes \
    curl \
    tini \
    libcap2-bin \
    libglib2.0-0 \
    libx11-6 \
    libnss3 \
    wait-for-it \
    fonts-dejavu \
    fontconfig > /dev/null && \
  addgroup \
    --gid "${GRAYLOG_GID}" \
    --quiet \
    "${GRAYLOG_GROUP}" && \
  adduser \
    --disabled-password \
    --disabled-login \
    --gecos '' \
    --home ${GRAYLOG_HOME} \
    --uid "${GRAYLOG_UID}" \
    --gid "${GRAYLOG_GID}" \
    --quiet \
    "${GRAYLOG_USER}" && \
  setcap 'cap_net_bind_service=+ep' "${JAVA_HOME}/bin/java" && \
  # https://github.com/docker-library/openjdk/blob/da594d91b0364d5f1a32e0ce6b4d3fd8a9116844/8/jdk/slim-bullseye/Dockerfile#L105
  # https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
  find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf && \
  ldconfig && \
  apt-get remove --assume-yes --purge \
    apt-utils > /dev/null && \
  rm -f /etc/apt/sources.list.d/* && \
  apt-get clean > /dev/null && \
  apt autoremove --assume-yes > /dev/null && \
  rm -rf \
    /tmp/* \
    /var/cache/debconf/* \
    /var/lib/apt/lists/* \
    /var/log/* \
    /usr/share/X11 \
    /usr/share/doc/* 2> /dev/null


EXPOSE 9000
USER ${GRAYLOG_USER}
VOLUME ${GRAYLOG_HOME}/data
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
CMD ["server"]

# add healthcheck
HEALTHCHECK \
  --interval=10s \
  --timeout=2s \
  --retries=12 \
  CMD /health_check.sh

# -------------------------------------------------------------------------------------------------

LABEL maintainer="Graylog, Inc. <hello@graylog.com>" \
      org.label-schema.name="Graylog Docker Image" \
      org.label-schema.description="Official Graylog Docker image" \
      org.label-schema.url="https://www.graylog.org/" \
      org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.vcs-url="https://github.com/Graylog2/graylog-docker" \
      org.label-schema.vendor="Graylog, Inc." \
      org.label-schema.version=${GRAYLOG_VERSION} \
      org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=${BUILD_DATE}
