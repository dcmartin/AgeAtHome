FROM resin/raspberrypi3-debian:jessie

MAINTAINER dcmartin <github@dcmartin.com>

RUN apt-get update && apt-get install -q -y --no-install-recommends \
    bsd-mailx \
    motion \
    mutt \
    ssmtp \
    x264

# Copy and scripts
COPY script/* /usr/local/bin/ 
COPY config/motion.conf /etc/motion/motion.conf
COPY config/ssmtp.conf.gmail /root/.muttrc

EXPOSE 8080 8081
 
VOLUME ["/var/lib/motion"]
 
WORKDIR /var/lib/motion
 
CMD ["/usr/local/bin/dockmotion"]
