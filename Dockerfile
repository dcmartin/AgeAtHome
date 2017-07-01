FROM resin/raspberrypi3-debian:jessie

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
    python-pip \
    x264 \
    unzip \
    vsftpd \
    gcc

RUN apt-get install -q -y --no-install-recommends \
    bison \ 
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
      && sed -i -e"s/^.*listen=.*$/listen=YES/" /etc/vsftpd.conf \
      && sed -i -e"s/^.*listen_ipv6=.*$/listen_ipv6=NO/" /etc/vsftpd.conf \
      && sed -i -e"s/^.*anonymous_enable=.*$/anonymous_enable=YES/" /etc/vsftpd.conf

#
# MQTT clients (pub/sub)
#
RUN apt-get install -q -y --no-install-recommends \
    mosquitto-clients

#
# H264
#
# RUN cd /usr/src && git clone git://git.videolan.org/x264 && cd x264 && ./configure --host=arm-unknown-linux-gnueabi --enable-static --disable-opencl && make install

#
# FFMPEG
# https://github.com/FFmpeg/FFmpeg.git (OLD)
#
# RUN cd /usr/src &&  git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg && cd ffmpeg && ./configure --arch=armel --target-os=linux --enable-gpl --enable-libx264 --enable-nonfree && make install

#
# POCKET SPHINX
#
# RUN curl -L "https://sourceforge.net/projects/cmusphinx/files/sphinxbase/5prealpha/sphinxbase-5prealpha.tar.gz/download" | tar xzvf - 
# RUN curl -L "https://sourceforge.net/projects/cmusphinx/files/pocketsphinx/5prealpha/pocketsphinx-5prealpha.tar.gz/download" | tar xzvf - 

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
# Copy "motion" scripts 
#
COPY script/* /usr/local/bin/ 
COPY config/motion.conf /etc/motion/motion.conf
#
# Ports for motion (control and stream)
#
EXPOSE 8080 8081
#
# Create volume to store images & videos
#
VOLUME ["/var/lib/motion"]


#
# install packages for Pulse Audio
#
# RUN apt-get install -q -y --no-install-recommends \
#    gstreamer0.10-pulseaudio \
#    libao4 \
#    libasound2-plugins \
#    libgconfmm-2.6-1c2 \
#    libglademm-2.4-1c2a \
#    libpulse-dev \
#    libpulse-mainloop-glib0 \
#    libpulse0 \
#    libsox-fmt-pulse \
#    paman \
#    paprefs \
#    pavucontrol \
#    pavumeter \
#    pulseaudio \
#    pulseaudio-esound-compat \
#    pulseaudio-module-bluetooth \
#    pulseaudio-module-gconf \
#    pulseaudio-module-jack \
#    pulseaudio-module-lirc \
#    pulseaudio-module-x11 \
#    pulseaudio-module-zeroconf \
#    pulseaudio-utils \
#    oss-compat

# removed debugging
   # pulseaudio-esound-compat-dbg \
   # libpulse-mainloop-glib0-dbg \
   # libpulse0-dbg \
   # pulseaudio-dbg \
   # pulseaudio-module-lirc-dbg \
   # pulseaudio-module-zeroconf-dbg \

#
# Change default PA configuration for use of PS3Eye Camera
#
# RUN cp -fvp /etc/asound.conf /etc/asound.conf.ORIG 
# COPY config/asound.conf /etc/asound.conf
# RUN echo "pcm.pulse { type pulse } ctl.pulse { type pulse } pcm.!default { type pulse } ctl.!default { type pulse }" > /etc/asound.conf

# RUN cp -fvp /etc/libao.conf /etc/libao.conf.ORIG
# RUN sed -i "s,default_driver=alsa,default_driver=pulse,g" /etc/libao.conf 
# RUN echo "default_driver=pulse" > /etc/libao.conf 

# RUN cp -fvp /etc/modules /etc/modules.ORIG
# RUN echo "snd-bcm2835" >> /etc/modules

# RUN cp -fvp /etc/default/pulseaudio /etc/default/pulseaudio.ORIG
# RUN sed -i "s,DISALLOW_MODULE_LOADING=1,DISALLOW_MODULE_LOADING=0,g" /etc/default/pulseaudio
# RUN echo "DISALLOW_MODULE_LOADING=0" > /etc/default/pulseaudio

# RUN cp -fvp /etc/pulse/system.pa /etc/pulse/system.pa.ORIG
# RUN echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;192.168.0.0/24 auth-anonymous=1" >> /etc/pulse/system.pa
# RUN echo "load-module module-zeroconf-publish" >> /etc/pulse/system.pa

# RUN echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;192.168.0.0/24 auth-anonymous=1" >> /etc/pulse/default.pa
# RUN echo "load-module module-zeroconf-publish" >> /etc/pulse/default.pa

#
# daemon settings according to Pi-Musicbox ( https://github.com/woutervanwijk/Pi-MusicBox )
#
# RUN cp -fvp /etc/pulse/daemon.conf /etc/pulse/daemon.conf.ORIG
# append parameters
# RUN echo "high-priority = yes" >> /etc/pulse/daemon.conf
# RUN echo "nice-level = 5" >> /etc/pulse/daemon.conf
# RUN echo "exit-idle-time = -1" >> /etc/pulse/daemon.conf
# RUN echo "resample-method = src-sinc-medium-quality" >> /etc/pulse/daemon.conf
# RUN echo "default-sample-format = s16le" >> /etc/pulse/daemon.conf
# RUN echo "default-sample-rate = 48000" >> /etc/pulse/daemon.conf
# RUN echo "default-sample-channels = 2" >> /etc/pulse/daemon.conf

# setup PATHs in bash(1)
# RUN echo "export LD_LIBRARY_PATH=/usr/local/lib" >> ~/.bashrc
# RUN echo "export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig" >> ~/.bashrc

# sphinxbase install ( required to install pocketsphinx )
# RUN apt-get install -y bison

# cd ~pi/
# wget  http://downloads.sourceforge.net/project/cmusphinx/sphinxbase/0.8/sphinxbase-0.8.tar.gz
# tar -xvf sphinxbase-0.8.tar.gz
# cd sphinxbase-0.8
# ./configure
# make
# sudo make install
# cd -
# 
# # pocketsphinx install
# # set this: LD_LIBRARY_PATH=/path/to/pocketsphinxlibs /usr/local/bin/pocketsphinx_continuous
# # http://www.voxforge.org/home/forums/message-boards/speech-recognition-engines/howto-use-pocketsphinx
# wget http://sourceforge.net/projects/cmusphinx/files/pocketsphinx/0.8/pocketsphinx-0.8.tar.gz
# tar -xvf pocketsphinx-0.8.tar.gz
# cd pocketsphinx-0.8
# ./configure
# make
# sudo make install
# cd -
# 
# # install sphinxtrain
# wget http://sourceforge.net/projects/cmusphinx/files/sphinxtrain/1.0.8/sphinxtrain-1.0.8.tar.gz
# tar -xvf sphinxtrain-1.0.8
# cd sphinxtrain-1.0.8
# ./configure
# make
# sudo make install
# cd -

#
# Run daemon
#
# RUN /usr/bin/pulseaudio --start --log-target=syslog --system=false
# RUN pocketsphinx_continuous -lm /home/pi/scarlettPi/config/speech/lm/scarlett.lm -dict /home/pi/scarlettPi/config/speech/dict/scarlett.dic -hmm /home/pi/scarlettPi/config/speech/model/hmm/en_US/hub4wsj_sc_8k -silprob  0.1 -wip 1e-4 -bestpath 0

#
# start Node.Red
#
# RUN node-red-start

ENV AUDIODEV hw:1,0
ENV AUDIODRIVER alsa
#
# set working directory
#
WORKDIR /var/lib/motion
#
# invoke motion detection script (NOT as daemon; re-direct logging to STDERR)
#
CMD [ "/usr/local/bin/dockmotion" ]
