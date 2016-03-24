# AgeAtHome

A cognitive surveillance solution deployed via resin.io to RaspberryPi based on 
[dockmotion](http://www.github.com/kfei/dockmotion)
which is a Dockerization of a surveillance solution:
[Motion](http://www.lavrsen.dk/foswiki/bin/view/Motion/WebHome)

The deliverable can be deployed using resin.io to any RaspberryPi2/3 with attached
Playstation3 Eye camera (via USB cable).

Modifications have been made to the [dockmotion] repository to address
considerations for resin.io operational semantics, e.g. requiring motion(1) to
NOT run in daemon mode to keep the "application" (resin.io terminology) active.

Environment variables control various aspects of operation:

1 MAILTO (default: none)
2 GMAIL_USER (default: none)
3 GMAIL_PASS (default: none)
4 TIMEZONE (default: America/Los_Angeles)
5 MOTION_PIXELS (default: 640x480)
6 MOTION_THRESHOLD (default: 1500)
7 MOTION_EVENT_GAP (default: 10)
8 MOTION_TIMELAPSE (default: unset)
9 WEBCONTROL_PORT (default: 8080)
10 STREAM_PORT (default: 8081)
11 VISUAL_USERNAME (default: none)
12 VISUAL_PASSWORD (default: none)
13 VISUAL_URL (default: none)

These environment variables are defined for the application; some are defined
only for the device (e.g. TIMEZONE).

## Quick Start

1) Copy this repository to your local GIT directory using the desktop GitHub application
	https://github.com/dcmartin/AgeAtHome.git
2) Setup resin.io
	https://dashboard.resin.io/signup
	- Create application (team setup TBD)
	- Configure and download image to flash RaspberryPi (n.b. note selection of WiFi to specify SSID and password)
3) Add resin as "push" target for repository
	git remote add resin <your_resinid>@git.resin.io:<your_resinid>/ageathome.git
4) Push master to resin
	git push resin master

### Build or pull the image (OLD)

Then build your own dockmotion Docker image:
```bash
docker build -t dockmotion .
```

Note that a pre-built image is also available:
```bash
docker pull kfei/dockmotion
```

### Custom settings (OLD)

Modify the [sample](config/motion.conf?raw=true) `motion.conf` to
suit your webcam, e.g., videodevice, v4l2_palette, etc.

If using Gmail, change account and password settings in the
[sample](config/ssmtp.conf.gmail?raw=true) and save it as `ssmtp.conf`.

### Run (OLD)

```bash
docker run -it --device=/dev/video0
    -p 8081:8081 \
    -e TIMEZONE="Asia/Taipei" \
    -e MAILTO="kfei@kfei.net" \
    -v /data-store:/var/lib/motion \
    -v /path/to/motion.conf:/etc/motion/motion.conf \
    -v /path/to/ssmtp.conf:/etc/ssmtp/ssmtp.conf \
    dockmotion
```

Note that:
  - The `--device` flag should be replaced by your webcam's device ID.
  - Expose port 8081 so that you can watch the live streaming, e.g., `vlc
    http://localhost:8081`.
  - Set `TIMEZONE` to `Asia/Taipei` instead of using UTC time.
  - All alarm mails will be sent to the e-mail address provided by `MAILTO`.
  - Mount a volume to `/var/lib/motion` for container since there might be lots
    of images and videos produced by Motion.

## Runtime Configs (OLD)

There are some environment variables can be supplied at run time:
  - `TIMEZONE` is for correct time stamp when motion detected. Check
    `/usr/share/zoneinfo` or see the [full list of time
    zones](http://en.wikipedia.org/wiki/List_of_tz_database_time_zones).
  - `MAILTO` to specify who will receive the alarm e-mails. Please make sure
    you set up this correctly.

Settings in `motion.conf` can be overridden:
    Note that the size must be supported by your webcam.
  - `MOTION_PIXELS` to specify the capture size of image, e.g., `1280x720`.
  - `MOTION_THRESHOLD` for `threshold`.
  - `MOTION_EVENT_GAP` for `event_gap`.
  - `MOTION_TIMELAPSE` for the time-lapse mode, e.g., `600,86400`. Please see below for further explanation.

## The Time-lapse Mode

Using dockmotion to capture
[time-lapse](http://en.wikipedia.org/wiki/Time-lapse_photography) videos is
quite easy. The `MOTION_TIMELAPSE` environment variable has two parts:
**interval** and **duration**, both in seconds. For instance, if a `-e
MOTION_TIMELAPSE="600,86400"` is supplied, Motion will capture images every 10
minutes within 24 hours. Note that in time-lapse mode, the motion detection
will be disabled.

An example run, for capturing one frame per hour within a week:
```bash
docker run -it --device=/dev/video0
    -e MOTION_PIXELS="1280x720" \
    -e MOTION_TIMELAPSE="3600,604800" \
    -v /data-store:/var/lib/motion \
    -v /path/to/motion.conf:/etc/motion/motion.conf \
    dockmotion
```
Now a weekly time-lapse video will be in `/data-store`.

A cool time-lapse:

![GIF](.screenshots/timelapse.gif?raw=true)

(If you happen to know the author of this time-lapse, please let me know so I
may source them properly.)

## Hooks

There are many types of hook can be set in Motion. For instance,
dockmotion just provides an e-mail notification script as the `on_event_end`
hook. Please dig into `motion.conf` and define your own hooks.

## Screenshots

- E-mail Notification
![Image](.screenshots/scrot1.jpg?raw=true)

- HTTP Live Streaming
![Image](.screenshots/scrot2.jpg?raw=true)
