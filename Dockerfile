FROM quay.io/centos/centos:stream8

USER root

EXPOSE 27017

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

ENV MONGODB_HOME=/var/lib/mongo \
    UID=2500

WORKDIR /var/lib/mongo

COPY ./mongodb-org.repo /etc/yum.repos.d/

RUN yum clean all
RUN yum -y update
RUN yum -y install mongodb-org-server mongodb-org-shell mongodb-org-tools mongodb-mongosh vim tmux python2 python2-pip bind-utils
RUN yum clean all
RUN chown -v -R ${UID}:${UID} /var/lib/mongo
RUN chown -v -R ${UID}:${UID} /var/log/mongodb
RUN install --verbose --owner=${UID} --group=${UID} --mode=770 --directory /data/{db,configdb} "${MONGODB_HOME}"/tls

VOLUME ["/data/db","/data/configdb"]

RUN pip2 install pymongo[tls]==3.11.3

USER ${UID}

COPY config/* /etc/

COPY scripts/* /usr/local/bin/
