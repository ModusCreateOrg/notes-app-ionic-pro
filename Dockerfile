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
        bsdmainutils \
        ca-certificates \
        curl \
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
        oracle-java8-set-default \
        yarn \
    && apt-get clean autoclean \
    && apt-get -y autoremove \
    && rm -rf /var/lib/{apt,dpkg}/ \
    && rm -rf /var/cache/oracle-jdk8-installer \
    && ln -s /usr/lib/jvm/java-8-oracle /usr/lib/jvm/default-java \
    && export DEBIAN_FRONTEND=newt

# Install fixuid.
# See: https://boxboat.com/2017/07/25/fixuid-change-docker-container-uid-gid/
RUN addgroup --gid $GID $GROUP \
    && adduser --uid $UID --ingroup $GROUP --home /home/$USER --shell $SHELL --disabled-password --gecos "" $USER \
    && curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.3/fixuid-0.3-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - \
    && chown root:root /usr/local/bin/fixuid \
    && chmod 4755 /usr/local/bin/fixuid \
    && mkdir -p /etc/fixuid \
    && printf "user: $USER\ngroup: $GROUP\n" > /etc/fixuid/config.yml

# Install the latest jq.
RUN wget -nv -O /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
    && chmod +x /usr/local/bin/jq

# Install Android SDK.
RUN wget -nv https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip \
    && echo "92ffee5a1d98d856634e8b71132e8a95d96c83a63fde1099be3d86df3106def9 sdk-tools-linux-4333796.zip" > SHA256SUMS \
    && sha256sum -c SHA256SUMS | grep OK \
    && unzip -q sdk-tools-linux-4333796.zip -d /opt/android-sdk \
    && chown -R $USER:$GROUP /opt/android-sdk \
    && rm sdk-tools-linux-4333796.zip SHA256SUMS

# Install Gradle.
RUN wget -nv https://services.gradle.org/distributions/gradle-4.6-bin.zip \
    && unzip -q gradle-4.6-bin.zip -d /opt/gradle \
    && rm gradle-4.6-bin.zip \
    && ln -s /opt/gradle/gradle-4.6/bin/gradle /usr/bin/gradle

USER $USER:$GROUP

ENV ANDROID_HOME /opt/android-sdk
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV PATH ${PATH}:$ANDROID_HOME:/home/$USER/.yarn/bin:/home/$USER/.local/bin

# We'll need the scripts in './ci/' for the next step so let's copy it over.
WORKDIR $HOME/builds
COPY ./package.json .
COPY ./ci ./ci
RUN ./ci/install/dependencies.sh
COPY . .

# Accept Android SDK licences, install the required SDK's and update them.
RUN mkdir -p ~/.android \
    && touch ~/.android/repositories.cfg \
    && yes | $ANDROID_HOME/tools/bin/sdkmanager --licenses \
    && $ANDROID_HOME/tools/bin/sdkmanager "platforms;android-$ANDROID_API_LEVEL" "build-tools;$ANDROID_BUILD_TOOLS_VERSION" \
    && $ANDROID_HOME/tools/bin/sdkmanager --update

CMD ["bash"]
