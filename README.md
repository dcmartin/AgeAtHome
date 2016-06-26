# AgeAtHome

[![Join the chat at https://gitter.im/dcmartin/AgeAtHome](https://badges.gitter.im/dcmartin/AgeAtHome.svg)](https://gitter.im/dcmartin/AgeAtHome?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

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

These environment variables are defined for the application:

WEBCONTROL_PORT (default: 8080)
STREAM_PORT (default: 8081)

For the device (e.g. TIMEZONE).

TIMEZONE (default: America/Los_Angeles)
MOTION_PIXELS (default: 640x480)
MOTION_THRESHOLD (default: 1500)
MOTION_EVENT_GAP (default: 10)
MOTION_TIMELAPSE (default: unset)

VISUAL_USERNAME (default: none)
VISUAL_PASSWORD (default: none)
VISUAL_URL (default: none)

ALCHEMY_API_KEY (default: none)
ALCHEMY_API_KEY_AM (default: none)
ALCHEMY_API_KEY_PM (default: none)
ALCHEMY_API_URL (default: none)

## Quick Start

1) Copy this repository to your local GIT directory using the desktop GitHub application
	https://github.com/dcmartin/AgeAtHome.git
2) Setup resin.io
	https://dashboard.resin.io/signup
	- Create application (team setup TBD)
	- Configure and download image to flash RaspberryPi (n.b. note selection of WiFi to specify SSID and password)
	- Wait for device to come on-line (...)
	- Define application and device environment variables
3) Add resin as "push" target for repository
	git remote add resin <your_resinid>@git.resin.io:<your_resinid>/ageathome.git
4) Push master to resin
	git push resin master

## Hooks

There are many types of hook can be set in Motion. For instance,
dockmotion just provides an e-mail notification script as the `on_event_end`
hook. Please dig into `motion.conf` and define your own hooks.

## Screenshots

