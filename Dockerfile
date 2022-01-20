FROM quay.io/ukhomeofficedigital/centos-base:a53308163ef47fb091c1aef1baf7f9dccd61cbe4

USER root

EXPOSE 27017

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

ENV MONGODB_HOME=/var/lib/mongo \
    UID=2500

WORKDIR /var/lib/mongo

COPY ./mongodb-org.repo /etc/yum.repos.d/

RUN yum clean all && \
    yum -y install epel-release && \
    yum -y install mongodb-org-server mongodb-org-shell mongodb-org-tools python2-pip && \
    yum clean all && \
    chown -v -R ${UID}:${UID} /var/lib/mongo && \
    chown -v -R ${UID}:${UID} /var/log/mongodb && \
    install --verbose --owner=${UID} --group=${UID} --mode=770 --directory /data/{db,configdb} "${MONGODB_HOME}"/tls

VOLUME ["/data/db","/data/configdb"]

RUN pip2 install pymongo[tls]==3.11.3

USER ${UID}

COPY config/* /etc/

COPY scripts/* /usr/local/bin/
