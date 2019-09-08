FROM openjdk:8-jre-alpine

RUN mkdir -p /opengrok/dist
RUN wget https://github.com/oracle/opengrok/releases/download/1.3.1/opengrok-1.3.1.tar.gz \
     && tar -C /opengrok/dist --strip-components=1 -xzf opengrok-1.3.1.tar.gz \
     && rm opengrok-1.3.1.tar.gz

RUN mkdir /usr/local/tomcat
RUN wget https://www-eu.apache.org/dist/tomcat/tomcat-9/v9.0.24/bin/apache-tomcat-9.0.24.tar.gz \
     && tar -C /usr/local/tomcat --strip-components=1 -xzf apache-tomcat-9.0.24.tar.gz \
     && rm apache-tomcat-9.0.24.tar.gz

RUN apk add --no-cache git ctags python3
RUN python3 -m pip install /opengrok/dist/tools/opengrok-tools.tar.gz

# compile and install universal-ctags
RUN git clone https://github.com/universal-ctags/ctags /tmp/ctags \
     && cd /tmp/ctags \
     && apk add --no-cache --virtual=build-dependencies autoconf automake build-base pkgconfig \
     && ./autogen.sh && ./configure && make && make install \
     && apk del build-dependencies && rm -rf /tmp/ctags

# environment variables
ENV SRC_ROOT /opengrok/src
ENV DATA_ROOT /opengrok/data
ENV OPENGROK_WEBAPP_CONTEXT /
ENV OPENGROK_TOMCAT_BASE /usr/local/tomcat
ENV OPENGROK_INDEX_OPTIONS="-H -P -S -G"
ENV CATALINA_HOME /usr/local/tomcat
ENV CATALINA_BASE /usr/local/tomcat
ENV CATALINA_TMPDIR /usr/local/tomcat/temp
ENV PATH $CATALINA_HOME/bin:$PATH
ENV JRE_HOME /usr
ENV CLASSPATH /usr/local/tomcat/bin/bootstrap.jar:/usr/local/tomcat/bin/tomcat-juli.jar

# custom deployment to / with redirect from /source
RUN rm -rf /usr/local/tomcat/webapps/* \
     && mkdir -p /opengrok/etc \
     && opengrok-deploy -c /opengrok/etc/configuration.xml /opengrok/dist/lib/source.war /usr/local/tomcat/webapps/ROOT.war \
     && mkdir "/usr/local/tomcat/webapps/source" \
     && echo '<% response.sendRedirect("/"); %>' > "/usr/local/tomcat/webapps/source/index.jsp"

# disable all file logging
RUN wget https://raw.githubusercontent.com/oracle/opengrok/c78a27b2fd095cdc8e7f2064f64ce70acbbbbbc4/docker/logging.properties -O /usr/local/tomcat/conf/logging.properties
RUN sed -i -e 's/Valve/Disabled/' /usr/local/tomcat/conf/server.xml

# indexing
RUN mkdir -p /opengrok/src /opengrok/data
ADD src.tar.gz /opengrok/src/
RUN opengrok-indexer \
     -a /opengrok/dist/lib/opengrok.jar -- \
     -c /usr/local/bin/ctags \
     -s /opengrok/src \
     -d /opengrok/data \
     $OPENGROK_INDEX_OPTIONS \
     -W /opengrok/etc/configuration.xml

EXPOSE 8080
WORKDIR $CATALINA_HOME
CMD ["catalina.sh", "run"]