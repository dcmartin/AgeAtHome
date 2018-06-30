FROM resin/raspberrypi3-node:6

MAINTAINER dcmartin <github@dcmartin.com>

#
# install packages for "motion" and mail support
#
RUN apt-get update 
RUN apt-get install -q -y --no-install-recommends \
    apt-utils \
    csh \
    git \
    make \
    tcsh \
    bc \
    gawk \
    motion \
    imagemagick \
    sysstat rsync ssh \
    curl \
    python2.7-dev \
    python3.4-dev \
    python-pip \
    python3-pip \
    x264 \
    unzip \
    vsftpd \
    gcc

RUN apt-get install -q -y --no-install-recommends \
    bison \ 
    flex \
    gperf \
    dateutils \
    alsa-base \
    alsa-utils \
    libasound2-dev \
    libtool \
    sox \
    autoconf \
    automake

#
# JQ v 1.5
#
RUN cd /usr/src \
	&& curl -L "https://github.com/stedolan/jq/releases/download/jq-1.5/jq-1.5.tar.gz" > jq.gz \
	&& tar xzvf jq.gz \
	&& cd jq-1.5 \ 
	&& autoreconf -i \
	&& ./configure \
	&& make \
	&& make install \
	&& make distclean

#
# VSFTPD
#
RUN echo "anon_root=/var/lib/motion" >> /etc/vsftpd.conf \
      && echo "anon_upload_enable=YES" >> /etc/vsftpd.conf \
      && sed -i -e"s/^.*listen=.*$/listen=YES/" /etc/vsftpd.conf \
      && sed -i -e"s/^.*listen_ipv6=.*$/listen_ipv6=NO/" /etc/vsftpd.conf \
      && sed -i -e"s/^.*write_enable=.*$/write_enable=YES/" /etc/vsftpd.conf \
      && sed -i -e"s/^.*anonymous_enable=.*$/anonymous_enable=YES/" /etc/vsftpd.conf

#
# MQTT clients (pub/sub)
#
RUN apt-get install -q -y --no-install-recommends \
    mosquitto-clients

#
# ALSA (http://julius.sourceforge.jp/forum/viewtopic.php?f=9&t=66)
#
RUN echo 'pcm.array { type hw card 1 }' >! ~/.asoundrc
RUN echo 'pcm.array_gain { type softvol slave { pcm "array" } control { name "Mic Gain" count 2 } min_dB -10.0 max_dB 5.0 }' >> ~/.asoundrc
RUN echo 'pcm.cap { type plug slave { pcm "array_gain" channels 4 } route_policy sum }' >> ~/.asoundrc

#
# install IBM IoTF quickstart
#
RUN echo "#! /bin/sh\nexit 0" > /usr/sbin/policy-rc.d
RUN curl -LO https://github.com/ibm-messaging/iot-raspberrypi/releases/download/1.0.2.1/iot_1.0-2_armhf.deb
RUN dpkg -i iot_1.0-2_armhf.deb

#
# resin-electron dependencies
#

RUN apt-get update && apt-get install -y \
  apt-utils \
  clang \
  xserver-xorg-core \
  xserver-xorg-input-all \
  xserver-xorg-video-fbdev \
  xorg \
  florence \ 
  libdbus-1-dev \
  libgtk2.0-dev \
  libnotify-dev \
  libgnome-keyring-dev \
  libgconf2-dev \
  libasound2-dev \
  libcap-dev \
  libcups2-dev \
  libxtst-dev \
  libxss1 \
  libnss3-dev \
  fluxbox \
  libsmbclient \
  libssh-4 \
  fbset \
  libexpat-dev && rm -rf /var/lib/apt/lists/*

# Set Xorg and FLUXBOX preferences
RUN mkdir ~/.fluxbox
RUN echo "xset s on" > ~/.fluxbox/startup \
  && echo "xserver-command=X -s 2 -v -dpms" >> ~/.fluxbox/startup \
  && echo "#!/bin/bash" > /etc/X11/xinit/xserverrc \
  && echo "" >> /etc/X11/xinit/xserverrc \
  && echo 'exec /usr/bin/X -s 2 -v -dpms -nocursor -nolisten tcp "$@"' >> /etc/X11/xinit/xserverrc

# Move to app dir
WORKDIR /usr/src/app

# Move package.json to filesystem
COPY ./app/package.json ./

# Install npm modules for the application
RUN JOBS=MAX npm install --unsafe-perm --production \
        && npm cache clean && node_modules/.bin/electron-rebuild

# Move app to filesystem
COPY ./app ./

## uncomment if you want systemd
ENV INITSYSTEM on

# audio drivers
ENV AUDIODEV hw:1,0
ENV AUDIODRIVER alsa

# Copy "motion" scripts 
COPY script/* /usr/local/bin/ 
COPY config/motion.conf /etc/motion/motion.conf

# Ports for motion (control and stream)
EXPOSE 8080 8081

# Create volume to store images & videos
VOLUME ["/var/lib/motion"]

# set working directory
WORKDIR /var/lib/motion

# invoke motion detection script (NOT as daemon; re-direct logging to STDERR)
CMD [ "/usr/local/bin/dockmotion" ]
