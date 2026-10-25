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
curl -fsSLO https://raw.githubusercontent.com/carlosbravoa/low-poly-race-server/main/scripts/install.sh
sudo sh install.sh https://.../raceserver-1.4.5-linux-x86_64.tar.gz SHA256
```

The server runs as the `raceserver` user from `/opt/raceserver`, as a service. Open UDP 7777 on the box's
firewall (and forward it on the router for players outside). Settings: `/etc/raceserver.env`, then
`systemctl restart raceserver`.

## In Docker

```sh
docker build --build-arg RELEASE_URL=https://.../raceserver-1.4.5-linux-x86_64.tar.gz -t lowpolyrace/server docker/
docker run -d --name raceserver --restart unless-stopped -p 7777:7777/udp -e NAME="My server" lowpolyrace/server
```

or `docker compose -f docker/docker-compose.yml up -d` with `RELEASE_URL` set. Environment: `NAME`, `PASSWORD`,
`PORT`, `ROOMS`, `SNAPSHOT_HZ` (60 on a LAN), `EXTRA` (more options). The LAN beacon (the game finding the server
by itself) needs `--network host`.

## On a LAN

Two ways. Both are found by the other games by themselves: a server announces itself on the network once a
second, and every game on it lists it under PLAY → ONLINE → *On the LAN*.

**From inside the game, no server at all.** One person: PLAY → ONLINE, *Host on this PC* → YES, then
**HOST AND ENTER THE LOBBY**. A server runs inside their game (snapshots at 60 Hz, the LAN rate) and they land in
its lobby, where they OPEN A ROOM. The page shows this PC's address (`192.168.x.y:7777`) to read out to anyone
whose game does not list the server. Everyone else: PLAY → ONLINE, pick the server under *On the LAN* (or type
the address under *Server*), CONNECT, join the room, pick a car, READY; the host presses START. The host's game
has to stay running: when they quit, the room is gone. Right for a living room or a club evening.

**A standalone server on one machine.** Unpack the tarball anywhere and run it:

```sh
tar -xzf raceserver-1.4.5-linux-x86_64.tar.gz
cd raceserver-1.4.5-linux-x86_64
./raceserver --tracks ./tracks --name "Saturday" --snapshot-hz 60
```

It keeps running as players come and go, holds several rooms, and nobody's game is special. As a service that
starts with the machine: `scripts/install.sh` (above). In Docker: `--network host`, so the announcement reaches
the LAN.

What can get in the way:

- A firewall on the host must let **UDP 7777 in** (the game); on the players' machines, **UDP 7778 in** (the
  announcement). When the announcement does not get through (a firewall, a Wi-Fi access point that isolates its
  clients, a network that drops broadcasts), the server still works: type its address under *Server*.
- Everyone needs the same game version: the protocol is versioned, and a mismatch is refused with a message.
- Wi-Fi jitter matters more than bandwidth (ten cars at 60 Hz is about 47 kB/s to each player). The game adapts
  its lead on the server's clock to the jitter it sees, but a host on a cable is the nicer evening.

## A series of races

In a room, the host's *Races* row sets 1 (one race on the chosen track) or 2 to 10: a series of that many
races on tracks the server draws at random, with points for the top nine (12-10-8-6-5-4-3-2-1) across the
races, the standings in the room between them and a champion at the end. START after the last race begins a
new series on new tracks. Changing *Races* starts the series over.

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
