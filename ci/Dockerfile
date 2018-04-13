FROM ubuntu:14.04
MAINTAINER Housni Yakoob <housni.yakoob@moduscreate.com>

ARG GID
ARG UID
ARG USER
ARG GROUP
ARG SHELL=/bin/bash

# The yarn repository requires `apt-transport-https`.
# curl requires the `ca-certificates` bundle.
# `add-apt-repository` is in `software-properties-common`.
# We set DEBIAN_FRONTEND back to its default value (newt) so inherited images behave as expected.
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        apt-transport-https \
        ca-certificates \
        curl \
        jq \
        python-pip \
        software-properties-common \
        unzip \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections \
    && add-apt-repository -y ppa:webupd8team/java \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        oracle-java8-installer \
        yarn \
    && apt-get clean autoclean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/{apt,dpkg}/ \
    && rm -rf /var/cache/oracle-jdk8-installer \
    && ln -s /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java \
    && export DEBIAN_FRONTEND=newt

RUN addgroup --gid $GID $GROUP \
    && adduser --uid $UID --ingroup $GROUP --home /home/$USER --shell $SHELL --disabled-password --gecos "" $USER
RUN curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.3/fixuid-0.3-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - \
    && chown root:root /usr/local/bin/fixuid \
    && chmod 4755 /usr/local/bin/fixuid \
    && mkdir -p /etc/fixuid \
    && printf "user: $USER\ngroup: $GROUP\n" > /etc/fixuid/config.yml

# Install Android SDK.
RUN wget -O /tmp/sdk-tools-linux-3859397.zip https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip \
    && unzip /tmp/sdk-tools-linux-3859397.zip -d /opt/android-sdk \
    && chown -R $USER:$GROUP /opt/android-sdk \
    && rm /tmp/sdk-tools-linux-3859397.zip

# Install Gradle.
RUN wget -O /tmp/gradle-4.6-bin.zip https://services.gradle.org/distributions/gradle-4.6-bin.zip \
    && unzip /tmp/gradle-4.6-bin.zip -d /opt/gradle \
    && rm /tmp/gradle-4.6-bin.zip \
    && ln -s /opt/gradle/gradle-4.6/bin/gradle /usr/bin/gradle

USER $USER:$GROUP

ENV JAVA_HOME /usr/lib/jvm/java-8-oracle
ENV ANDROID_HOME /opt/android-sdk
ENV PATH ${PATH}:$ANDROID_HOME
ENV PATH ${PATH}:/home/$USER/.yarn/bin:/usr/local/bin:/home/$USER/.local/bin

COPY ./ $HOME/builds
WORKDIR $HOME/builds
RUN ./install/dependencies.sh

# Accept Android SDK licences, install the required SDK's and update them.
RUN yes | $ANDROID_HOME/tools/bin/sdkmanager --licenses \
    && $ANDROID_HOME/tools/bin/sdkmanager "platforms;android-26" "build-tools;26.0.2" \
    && $ANDROID_HOME/tools/bin/sdkmanager --update

CMD ["bash"]