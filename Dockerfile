FROM ubuntu:18.04
RUN apt update && apt install -y net-tools ipset iptables iproute2 iputils-ping gettext-base
RUN mkdir -p /opt/v2ray
COPY ./v2ray ./v2ctl ./config.json.template ./init.sh ./geoip.dat ./geosite.dat /opt/v2ray/
CMD ["/bin/bash", "/opt/v2ray/init.sh"]