# used to select which java version in the build cmd
# --build-arg java=??
ARG java=17


FROM amazoncorretto:${java}-alpine3.18-jdk as buildjre
ARG java
RUN [ "${java}" -eq 8 ] \
    # just copy the jre, java 8 doesn't have the jlink tool
    &&  { mkdir customjre && cp -a ${JAVA_HOME}/* /customjre ; } \
    # jlink --strip-debug needs objcopy
    || apk add --no-cache binutils \
    # build a custom slim jre, optimized
    && $JAVA_HOME/bin/jlink \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=0 \
    --add-modules ALL-MODULE-PATH \
    --output /customjre


FROM alpine:3.18
LABEL org.opencontainers.image.authors="ilightwas <ilightwas@gmail.com>"
LABEL org.opencontainers.image.url="https://github.com/ilightwas/mcservercontrol"

# script cmd from util-linux
# tail from coreutils
# ps from procps
# udev for the minecraft server
RUN apk add --no-cache util-linux coreutils procps udev \
    && adduser \
    --no-create-home \
    --disabled-password \
    --gecos "" \
    --uid 1000 \
    --shell /bin/sh \
    jeff
# Oh yes... It was Dora and Diego.. and Swiper

# for now, uid is hard coded
# the volume flies on the host should also have the same uid
USER 1000

ENV LANG=C.UTF-8
ENV JAVA_HOME=/jre
ENV PATH=${JAVA_HOME}/bin:${PATH}

COPY --from=buildjre /customjre ${JAVA_HOME}
COPY --chmod=755 mcservercontrol.sh /

# when running, mount a volume with server files here e.g. -v server_files_path:/server
WORKDIR /server

ENTRYPOINT ["/mcservercontrol.sh"]
