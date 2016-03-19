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

EXPOSE 80 81
 
VOLUME ["/var/lib/motion"]
 
WORKDIR /var/lib/motion
 
CMD ["/usr/local/bin/dockmotion"]
