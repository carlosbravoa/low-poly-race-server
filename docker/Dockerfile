# The Low Poly Race server in a container. Build with the release tarball's URL:
#   docker build --build-arg RELEASE_URL=https://.../raceserver-0.1.0-linux-x86_64.tar.gz -t lowpolyrace/server docker/
#   docker run -d --name raceserver -p 7777:7777/udp -e NAME="My server" lowpolyrace/server
# (a password: -e PASSWORD=word; the LAN beacon needs the host's network: --network host)
FROM debian:bookworm-slim
ARG RELEASE_URL
ARG RELEASE_SHA256=
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*
RUN set -e; curl -fsSL -o /tmp/server.tar.gz "$RELEASE_URL"; \
    if [ -n "$RELEASE_SHA256" ]; then echo "$RELEASE_SHA256  /tmp/server.tar.gz" | sha256sum -c -; fi; \
    mkdir -p /opt && tar -xzf /tmp/server.tar.gz -C /opt && mv /opt/raceserver-* /opt/raceserver && rm /tmp/server.tar.gz; \
    useradd -r -d /opt/raceserver -s /usr/sbin/nologin raceserver && chown -R raceserver:raceserver /opt/raceserver
USER raceserver
WORKDIR /opt/raceserver
ENV PORT=7777 NAME="Low Poly Race" PASSWORD= ROOMS=8 SNAPSHOT_HZ=30 EXTRA=
EXPOSE 7777/udp
CMD ["/bin/sh", "-c", "exec ./raceserver --tracks ./tracks --port $PORT --name \"$NAME\" --password \"$PASSWORD\" --rooms $ROOMS --snapshot-hz $SNAPSHOT_HZ $EXTRA"]
