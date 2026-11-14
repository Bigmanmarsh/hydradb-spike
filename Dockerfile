FROM ghcr.io/hydra-db/hydradb:0.4.0

USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 start.sh /usr/local/bin/start.sh

ENV RUST_MIN_STACK=33554432
EXPOSE 8443 10000
ENTRYPOINT ["/usr/local/bin/start.sh"]
