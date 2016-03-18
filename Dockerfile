FROM resin/raspberrypi3-debian:jessie

MAINTAINER kfei <kfei@kfei.net>

RUN apt-get update && apt-get install -q -y --no-install-recommends \
    bsd-mailx \
    motion \
    mutt \
    ssmtp \
    x264

# Copy and scripts
COPY script/* /usr/local/bin/ 

EXPOSE 9090
EXPOSE 9091
 
VOLUME ["/var/lib/motion"]
 
WORKDIR /var/lib/motion
 
ENTRYPOINT ["/usr/local/bin/dockmotion"]
