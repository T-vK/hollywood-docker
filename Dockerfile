FROM ubuntu:18.04

# Copy hollywood source code into the Docker image
COPY . /hollywood/

# Install some basic requirements and ensure that everything will work without interaction
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles
RUN \
  rm -f /etc/dpkg/dpkg.cfg.d/excludes && \
  apt-get update -qq && \
  dpkg -l | grep ^ii | cut -d' ' -f3 | xargs apt-get install -qqy --reinstall && \
  apt-get install -qqy debmake debhelper git man tzdata mlocate && \
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
  dpkg-reconfigure tzdata
  
# Build deb files
RUN \
  VERSION="$(cat /hollywood/debian/changelog | head -n 1 | cut -d '(' -f2 | cut -d '-' -f1)" && \
  mv /hollywood "/hollywood_${VERSION}" && \
  tar -czvf "hollywood_${VERSION}.orig.tar.gz" "hollywood_${VERSION}" && \
  cd "/hollywood_${VERSION}" && \
  DEBEMAIL=" " debmake && debuild -us -uc && \
  mv "/hollywood_${VERSION}" /hollywood

# Unfortunately, if we install hollywood from the built deb files it won't work correctly...
#RUN dpkg -i /*.deb; apt-get -f install -qqy && \

# So we are using the hollywood executable from /hollywood/bin because the one from the deb files doesn't work correctly.
ENV PATH="/hollywood/bin:${PATH}"

# But now we have to take care of the dependencies ourselves. We extract them with `dpkg -I` from our `deb`s and install them with `apt-get`
RUN \
  HOLLYWOOD_DEPENDENCIES=$(dpkg -I /hollywood*.deb | grep 'Depends: ' | tr -d ',' | cut -d ':' -f2) && \
  HOLLYWOOD_RECOMMENDS=$(dpkg -I /hollywood*.deb | grep 'Recommends: ' | tr -d ',' | cut -d ':' -f2) && \
  WALLSTREET_DEPENDENCIES=$(dpkg -I /hollywood*.deb | grep 'Depends: ' | tr -d ',' | cut -d ':' -f2) && \
  WALLSTREET_RECOMMENDS=$(dpkg -I /hollywood*.deb | grep 'Recommends: ' | tr -d ',' | cut -d ':' -f2) && \
  apt-get install -qqy $HOLLYWOOD_DEPENDENCIES $HOLLYWOOD_RECOMMENDS $WALLSTREET_DEPENDENCIES $WALLSTREET_RECOMMENDS

# Cleanup
RUN \
  ls -la && \
  rm -rf /hollywood_* /wallstreet_* && \
  apt-get remove -qqy debmake debhelper && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=
ENV TZ=

CMD [ "hollywood" ]
