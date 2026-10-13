# Low Poly Race — hosting a server

Everything needed to run a [Low Poly Race](https://github.com/carlosbravoa/low-poly-race) server for your friends,
your club or your LAN: on AWS with one CloudFormation template, in Docker, on any Linux box as a service, or
straight from a terminal. The server itself is a single static binary in a release tarball
(`raceserver-VERSION-linux-ARCH.tar.gz`), built from the game's source and published with its SHA-256 on
[this repository's releases page](https://github.com/carlosbravoa/low-poly-race-server/releases). This repository holds no game code: the templates, the scripts, the service unit and the wire
protocol.

What a server does: players connect from the game (PLAY → ONLINE), meet in the lobby, open rooms, pick their
cars and race; the server runs every room's race at 240 Hz and sends each player the others' positions; a
player's own car is predicted in their game and kept honest by the server (the netcode is described in the
game's `docs/online.md`). One UDP port in, nothing else. A ten-car room costs about a tenth of a vCPU; the
smallest instances hold several.

## On AWS in five minutes

1. Open the CloudFormation console in the region nearest the players (the ping is the game), **Create stack**,
   upload `cloudformation/raceserver.yaml`.
2. Fill in: the release tarball's URL and its SHA-256 (from the releases page here; pick the `arm64` one with
   the default `t4g.small`, or the `x86_64` one with a `t3.small`), a server name, a password if it is not for
   everyone.
3. Optional: a Route 53 hosted zone and a name (`race.example.com`), an SSH key pair, a narrower `AllowedCidr`.
4. Create. Three minutes later the stack's **Outputs** show `ServerAddress`: type it in the game.

What it makes: a security group with the one UDP port, a small EC2 instance on the latest Amazon Linux 2023
with a fixed public IP, an IAM role for Session Manager (a shell from the console, no key needed), and the
server installed as a `systemd` service that restarts by itself and starts with the machine. It costs what the
instance costs (a `t4g.small` is a few dollars a month; stop the instance when nobody races). To update to a
new release: a shell on the instance, `raceserver-install NEW_URL NEW_SHA256`. The settings live in
`/etc/raceserver.env`; the install log in `/var/log/raceserver-install.log`; the server's log in
`journalctl -u raceserver -f`.

## On any Linux box

```sh
curl -fsSLO https://raw.githubusercontent.com/cbravo/low-poly-race-server/main/scripts/install.sh
sudo sh install.sh https://.../raceserver-0.1.0-linux-x86_64.tar.gz SHA256
```

The server runs as the `raceserver` user from `/opt/raceserver`, as a service. Open UDP 7777 on the box's
firewall (and forward it on the router for players outside). Settings: `/etc/raceserver.env`, then
`systemctl restart raceserver`.

## In Docker

```sh
docker build --build-arg RELEASE_URL=https://.../raceserver-0.1.0-linux-x86_64.tar.gz -t lowpolyrace/server docker/
docker run -d --name raceserver --restart unless-stopped -p 7777:7777/udp -e NAME="My server" lowpolyrace/server
```

or `docker compose -f docker/docker-compose.yml up -d` with `RELEASE_URL` set. Environment: `NAME`, `PASSWORD`,
`PORT`, `ROOMS`, `SNAPSHOT_HZ` (60 on a LAN), `EXTRA` (more options). The LAN beacon (the game finding the server
by itself) needs `--network host`.

## On a LAN, no install

Unpack the tarball anywhere and run it:

```sh
./raceserver --tracks ./tracks --name "Saturday" --snapshot-hz 60
```

Every game on the network lists it under PLAY → ONLINE → *On the LAN*. The game itself can also host
(*Host on this PC* on the same page): no server to run at all for a couch session.

## Options

```
raceserver [--port 7777] [--name NAME] [--password WORD] [--tracks DIR] [--rooms 8] [--players 32]
           [--snapshot-hz 30] [--no-beacon] [--quiet]
```

`--no-beacon` on a cloud machine (nothing to announce to). `LPR_NET_DEBUG=1` in the environment logs, once a
second per seat, the input the server applied and when it ran late.

## The protocol

`PROTOCOL.md` describes the messages on the wire, so other tools can speak to a server (a lobby web page, a
monitoring probe). The game and the server refuse each other across protocol versions.

## Security

No accounts: a name and, if set, the server's password, in the clear over UDP (a password keeps strangers out
of a friends' server; it is not a secret worth more than that). The server trusts nothing from a game: the
physics runs on the server, inputs are pedals and steering. Open the one UDP port and nothing else.
