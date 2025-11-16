FROM tomcat:9-jdk17

ENV NEXUS_URL=http://107.23.250.183:8081
ENV NEXUS_REPO=maven-snapshots
ENV GROUP_PATH=ua/sergiishapoval/webcarrental/WebCarRental
ENV VERSION=1.0-SNAPSHOT

# Use raw password here
ARG NEXUS_USER=admin
ARG NEXUS_PASS=admin@123

RUN apt-get update && apt-get install -y curl && apt-get clean

# Remove Tomcat default ROOT
RUN rm -rf /usr/local/tomcat/webapps/ROOT

# Download metadata
RUN curl -f -u "$NEXUS_USER:$NEXUS_PASS" \
    "$NEXUS_URL/repository/$NEXUS_REPO/$GROUP_PATH/$VERSION/maven-metadata.xml" \
    -o /tmp/meta.xml

# Extract full snapshot version
RUN grep -oPm1 "(?<=<value>)[^<]+" /tmp/meta.xml > /tmp/full_version.txt

# Download WAR into ROOT.war (Tomcat will auto-extract)
RUN curl -f -u "$NEXUS_USER:$NEXUS_PASS" \
    "$NEXUS_URL/repository/$NEXUS_REPO/$GROUP_PATH/$VERSION/WebCarRental-$(cat /tmp/full_version.txt).war" \
    -o /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

CMD ["catalina.sh", "run"]
