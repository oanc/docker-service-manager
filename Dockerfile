# lappsgrid/service-manager
#
# A Lappsgrid Service Manager with the GATE and Stanford services installed.

FROM lappsgrid/ubuntu:1.0.0

MAINTAINER Keith Suderman, suderman@cs.vassar.edu

# Install tomcat to /usr/share
ADD ./packages/tomcat.tgz /usr/share/tomcat
ADD ./tomcat-startup.sh /etc/init.d/tomcat
ADD ./tomcat-users.xml /usr/share/tomcat/service-manager/conf/tomcat-users.xml
ADD ./service_manager.xml /usr/share/tomcat/service-manager/conf/Catalina/localhost/service_manager.xml
RUN chmod ug+x /etc/init.d/tomcat
# Create the log directories. These are not in the tgz file (since they were empty) and
# Tomcat chokes if they do not exist.
RUN mkdir /usr/share/tomcat/service-manager/logs && \
    mkdir /usr/share/tomcat/active-bpel/logs 

# Install LSD and LDDL executables to /usr/bin
ADD ./packages/lsd-latest.tgz /usr/bin

ADD ./packages/lddl.tgz /usr/bin
RUN chmod a+x /usr/bin/lsd && \
    chmod a+x /usr/bin/lddl

# Create the database for the Service Manager.
ADD ./create_storedproc.sql /tmp/create_storedproc.sql
USER postgres
RUN service postgresql start && \
	until pg_isready ; do echo "Waiting..." ; sleep 2; done && \
    createuser -S -D -R langrid && \
    psql --command "ALTER USER langrid WITH PASSWORD 'langrid'" && \
    createdb langrid -O langrid -E "UTF-8" && \
    psql langrid < /tmp/create_storedproc.sql && \
    psql langrid -c "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO langrid"

USER root	

# Create the tomcat account.  It is safe to ignore the warning from useradd that the
# user's HOME directory already exists.
RUN /usr/sbin/useradd -d /usr/share/tomcat -c "Apache Tomcat" -m -s /bin/nologin tomcat
RUN chown -R tomcat:tomcat /usr/share/tomcat

RUN apt-get update && apt-get install -y git
RUN git clone https://github.com/lappsgrid-incubator/lddl-scripts.git /etc/lddl

ADD ./service_manager.xml /usr/share/tomcat/service-manager/conf/Catalina/localhost/service_manager.xml
ADD ./startup-all.sh /usr/bin/startup
ADD ./shutdown.sh /usr/bin/shutdown
ADD ./tail-log.sh /usr/bin/taillog
RUN chmod ug+x /usr/bin/taillog && \
	chmod ug+x /usr/bin/shutdown


# Call our startup script when the container starts.
CMD [ "/usr/bin/startup" ]


