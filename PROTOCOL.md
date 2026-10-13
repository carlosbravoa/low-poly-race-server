# The wire protocol (version 1)

UDP, through [ENet](https://github.com/zpl-c/enet) (the single-header fork): two channels, 0 reliable (the lobby,
the rooms, a race's start and end, penalties, chat), 1 unreliable sequenced (snapshots) or unsequenced (inputs,
each in its own datagram). One port, 7777 by default. The server also broadcasts a beacon on the LAN
(UDP 7778, once a second): the bytes `LPR1`, the game port (u16), the server's name (str), players (u8), rooms
(u8).

## Bytes

Little-endian. `u8 u16 u32 i8 i16 i32 f32 f64`; `bool` a byte; `str` a byte of length then that many bytes
(UTF-8, at most 255). Quantised fields: `pos` three i32 in millimetres; `vel` three i16 in cm/s; `angvel`
three i16 in mrad/s; `quat` a byte naming the largest component (0 w, 1 x, 2 y, 3 z; it is positive and
implied) then the other three as i16 scaled by 32767/0.70711; `unit` a byte for 0..1; `sunit` an i16 for
-1..1. Every message starts with its type byte. A message that cannot be read to its end is dropped.

## Game → server

| type | name | fields |
|---|---|---|
| 1 | HELLO | version u32 (1), name str, password str, token u32 (0, or the one from a WELCOME to come back after a drop) |
| 2 | CREATE_ROOM | RoomSettings |
| 3 | JOIN_ROOM | room u32 |
| 4 | LEAVE_ROOM | |
| 5 | SETUP | model u8, paint u8, AssistSettings |
| 6 | READY | ready bool |
| 7 | START | (the host, while the room forms) |
| 8 | CHAT | text str |
| 9 | LOADED | (the track is loaded: the lights may go) |
| 10 | INPUT | tick u32 (of the newest), n u8, then n inputs oldest first: steer sunit, throttle unit, brake unit, handbrake unit, flags u8 (1 shift up, 2 shift down, 4 reset) |
| 11 | RESET | (the reset button; the game sends it in the input's flags instead) |
| 12 | PING | stamp u32 |
| 13 | ROOM_SETTINGS | RoomSettings (the host, while the room forms; everyone's ready flag is cleared) |

RoomSettings: track str (the file's name without `.track`), laps u8, model u8 (0 arcade, 1 balanced, 2
simulation), contact u8 (0 real, 1 arcade bumps, 2 ghost), aiFill bool, aiLevel u8 (0 easy, 1 medium, 2 hard).

AssistSettings: steering f32, counterSteer f32, stability f32, esc f32, tcs bool, abs bool, autoShift bool,
brakeReverse bool, speedSteer f32, steerRate f32, understeerControl f32, oversteerControl f32.

## Server → game

| type | name | fields |
|---|---|---|
| 64 | WELCOME | playerId u32, serverName str, snapshotHz u8, token u32, resumed bool |
| 65 | REJECT | reason str |
| 66 | LOBBY | serverName str, n u16 players (id u32, name str, room i32 or -1, ping u16 ms), n u8 rooms (RoomInfo), n u8 tracks (str) |
| 67 | ROOM | RoomInfo |
| 68 | RACE_START | room u32, RoomSettings, n u8 grid entries (name str, model u8, paint u8, seat i8 or -1 for the AI, playerId u32, pace f32), mySeat i8 (-1: watching), countdown f32 |
| 69 | SNAPSHOT | tick u32, goTick u32, phase u8 (0 countdown, 1 racing, 2 finished), countdownLeft f32, clock f64, inputLead i16, n u8 cars (CarState, in grid order) |
| 70 | RACE_END | n u8 results (name str, position u8, finished bool, finishTime f32, bestLap f32, seat i8) |
| 71 | PONG | stamp u32 |
| 72 | SAY | who str, text str |
| 73 | PENALTY | kind u8 (0 reset, 1 big crash, 2 heavy crash, 3 third big crash), g f32, hold f32 s, bigCount u8 |

RoomInfo: id u32, host u32 (a player id), RoomSettings, phase u8 (0 forming, 1 loading, 2 racing, 3 results),
n u8 members (id u32, name str, model u8, paint u8, AssistSettings, ready bool, seat i8), lap u8, leader str.

CarState (78 bytes): pos, quat, vel, angvel, steer sunit (road-wheel angle, rad), four wheel speeds i16 (×20
rad/s), four suspension compressions u8 (×500 m), contact u8 (bit i: wheel i on the ground), surface u8, engine
speed u16 (×20 rad/s), gear i8, throttle unit, brake unit, slip u8 (×60, the worst tire over its peak), flags
u8 (1 ghost, 2 finished), hold u16 (ticks the car is still held), position u8, crossings u8,
station f32, lastCross f32, bestLap f32, lastLap f32, finishTime f32.

## Time

The race steps at 240 Hz; `tick` counts its steps from the grid. The server holds the grid at tick 0 for 0.3 s
after the lights are ready (every player sees tick-0 snapshots and starts sending inputs from tick 0), then
steps; `goTick` is the first tick not held by the countdown. An input is applied at the tick it is tagged with;
if it has not arrived, the last one is applied again. `inputLead` in a snapshot tells its recipient how many
ticks early their newest input arrived (negative: late), which the game uses to run its clock far enough ahead.
A player who drops during a race keeps their seat for ten seconds (the AI drives); a HELLO with their token and
name within that time puts them back (`resumed` in the WELCOME, then a RACE_START with their seat).
