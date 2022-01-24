FROM quay.io/ukhomeofficedigital/centos-base:26b3cc460ee5ba775702eeaa11bf24464adc822c
FROM quay.io/ukhomeofficedigital/centos-base:a53308163ef47fb091c1aef1baf7f9dccd61cbe4

USER root

EXPOSE 27017

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

ENV MONGODB_HOME=/var/lib/mongo \
    UID=2500

WORKDIR /var/lib/mongo

COPY ./mongodb-org.repo /etc/yum.repos.d/

RUN yum clean all
RUN yum -y install epel-release
RUN yum -y install mongodb-org-server mongodb-org-shell mongodb-org-tools
RUN yum -y install python2 python2-pip
RUN yum clean all
RUN chown -v -R ${UID}:${UID} /var/lib/mongo
RUN chown -v -R ${UID}:${UID} /var/log/mongodb
RUN install --verbose --owner=${UID} --group=${UID} --mode=770 --directory /data/{db,configdb} "${MONGODB_HOME}"/tls

VOLUME ["/data/db","/data/configdb"]

RUN pip2 install pymongo[tls]==3.11.3

USER ${UID}

COPY config/* /etc/

COPY scripts/* /usr/local/bin/
