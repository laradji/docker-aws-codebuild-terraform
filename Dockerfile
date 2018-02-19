FROM ubuntu:16.04

ARG TERRAFORM_VERSION=0.11.3
ARG TERRAGRUNT_VERSION=0.14.0
ARG NODE_VERSION=8.x
ARG AWSCLI_VERSION=1.14.32
ARG GITLFS_VERSION=2.3.4
ARG CAPISTRANO_VERSION=3.10.1
ARG BOWER_VERSION=1.8.2
ARG COMPOSER_VERSION=1.6.3

ENV DOCKER_BUCKET="download.docker.com" \
    DOCKER_VERSION="17.09.0-ce" \
    DOCKER_CHANNEL="stable" \
    DOCKER_SHA256="a9e90a73c3cdfbf238f148e1ec0eaff5eb181f92f35bdd938fd7dab18e1c4647" \
    DIND_COMMIT="3b5fac462d21ca164b3778647420016315289034" \
    DOCKER_COMPOSE_VERSION="1.16.1"

RUN apt-get update && \
    # Install add-apt-repository
    apt-get install -y --no-install-recommends \
      software-properties-common && \
    # Update git and install utils
    add-apt-repository ppa:git-core/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      wget curl git openssh-client jq python make \
      ca-certificates tar gzip zip unzip bzip2 gettext-base \
      ruby-full php \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Install Nodejs
RUN curl -sL https://deb.nodesource.com/setup_"$NODE_VERSION" | bash -
RUN apt-get install -y --no-install-recommends nodejs

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && \
    apt-get install yarn

# Install AWS CLI
RUN wget "https://bootstrap.pypa.io/get-pip.py" -O /tmp/get-pip.py && \
    python /tmp/get-pip.py && \
    pip install awscli=="$AWSCLI_VERSION" && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install AWS ELASTIC BEANSTALK CLI
RUN pip install awsebcli --upgrade

# Install Terraform
RUN curl -sL https://releases.hashicorp.com/terraform/"$TERRAFORM_VERSION"/terraform_"$TERRAFORM_VERSION"_linux_amd64.zip -o terraform_"$TERRAFORM_VERSION"_linux_amd64.zip && \
    unzip terraform_"$TERRAFORM_VERSION"_linux_amd64.zip -d /usr/bin && \
    chmod +x /usr/bin/terraform

# Install Git LFS
RUN curl -sL https://github.com/git-lfs/git-lfs/releases/download/v"$GITLFS_VERSION"/git-lfs-linux-amd64-"$GITLFS_VERSION".tar.gz -o gitlfs.tar.gz && \
    mkdir -p gitlfs && \
    tar --extract --file gitlfs.tar.gz --strip-components 1 --directory gitlfs && \
    chmod +x gitlfs/install.sh && \
    ./gitlfs/install.sh

# Install Terragrunt
RUN curl -sL https://github.com/gruntwork-io/terragrunt/releases/download/v"$TERRAGRUNT_VERSION"/terragrunt_linux_amd64 -o /usr/bin/terragrunt && \
    chmod +x /usr/bin/terragrunt

# Install Capistrano
RUN gem install capistrano -v "$CAPISTRANO_VERSION"

# Install Bower
RUN npm install -g bower@"$BOWER_VERSION"

# Install Composer
RUN curl -s -f -L -o /tmp/installer.php https://raw.githubusercontent.com/composer/getcomposer.org/b107d959a5924af895807021fcef4ffec5a76aa9/web/installer \
 && php -r " \
    \$signature = '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061'; \
    \$hash = hash('SHA384', file_get_contents('/tmp/installer.php')); \
    if (!hash_equals(\$signature, \$hash)) { \
        unlink('/tmp/installer.php'); \
        echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
        exit(1); \
    }" \
 && php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION} \
 && composer --ansi --version --no-interaction \
 && rm -rf /tmp/* /tmp/.htaccess

# Install Docker with dind support
COPY dockerd-entrypoint.sh /usr/local/bin/

# From the docker:17.09
RUN set -x \
    && curl -fSL "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
    && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
    && tar --extract --file docker.tgz --strip-components 1  --directory /usr/local/bin/ \
    && rm docker.tgz \
    && docker -v \
# From the docker dind 17.09
    # && apt-get update && apt-get install -y --no-install-recommends \
    #           e2fsprogs=1.42.9-* iptables=1.4.21-* xfsprogs=3.1.9ubuntu2 xz-utils=5.1.1alpha+20120614-* \
    && apt-get update && apt-get install -y --no-install-recommends \
              e2fsprogs iptables xfsprogs xz-utils \
# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
    && addgroup dockremap \
    && useradd -g dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid \
    && wget "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
    && curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/dind /usr/local/bin/docker-compose \
# Ensure docker-compose works
    && docker-compose version \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean


VOLUME /var/lib/docker

ENTRYPOINT ["dockerd-entrypoint.sh"]
