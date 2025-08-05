# Start with a base Linux distribution (Ubuntu LTS is a good choice)
FROM ubuntu:24.04

ARG STUDENT_PASSWORD

# Validate that STUDENT_PASSWORD is provided
RUN test -n "$STUDENT_PASSWORD" || (echo "ERROR: STUDENT_PASSWORD build argument is required" && exit 1)

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install essential tools for LPIC-1
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  sudo \
  vim \
  nano \
  less \
  man-db \
  procps \
  psmisc \
  net-tools \
  iproute2 \
  iputils-ping \
  dnsutils \
  openssh-client \
  openssh-server \
  cron \
  at \
  rsyslog \
  systemd \
  systemd-sysv \
  parted \
  fdisk \
  lvm2 \
  xfsprogs \
  btrfs-progs \
  e2fsprogs \
  dosfstools \
  quota \
  tar \
  gzip \
  bzip2 \
  xz-utils \
  zip \
  unzip \
  # find \
  grep \
  sed \
  # awk \
  # wc \
  curl \
  wget \
  git \
  gcc \
  make \
  bind9-utils \
  apache2 \
  mariadb-server \
  postfix \
  cups \
  nfs-common \
  nfs-kernel-server \
  samba \
  squashfs-tools \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  /var/cache/apt/archives/*

# Create a non-root user for practice
# Use a more secure method to set the password that doesn't expose it in layer history
RUN useradd -m -s /bin/bash student && \
  printf '%s\n' "student:${STUDENT_PASSWORD}" | chpasswd && \
  adduser student sudo && \
  echo "student ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/student && \
  unset STUDENT_PASSWORD

# Set up SSH for remote access practice
RUN mkdir -p /var/run/sshd && \
  echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config

# Copy and set up the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports for services
EXPOSE 22 80 3306

# Use the startup script as the default command
CMD ["/usr/local/bin/entrypoint.sh"]

# Set working directory
WORKDIR /home/student

# Create a volume for the student home directory
VOLUME /home/student

# Switch to the student user
USER student

