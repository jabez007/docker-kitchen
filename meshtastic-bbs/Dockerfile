# From original Dockerfile at https://github.com/TheCommsChannel/TC2-BBS-mesh
FROM debian:stable-slim AS build

RUN apt update && \
  apt install -y \
  git \
  && apt clean && rm -rf /var/lib/apt/lists/*

# Clone the repository
RUN git clone https://github.com/TheCommsChannel/TC2-BBS-mesh.git

####

FROM --platform=$BUILDPLATFORM alpine:latest

# Install required packages
RUN apk add --update --no-cache \
  python3 \
  py3-pip

# Switch to non-root user
RUN adduser --disabled-password mesh
USER mesh
RUN mkdir -p /home/mesh/bbs
WORKDIR /home/mesh/bbs

# Copy over required files
COPY --from=build /TC2-BBS-mesh/*.py ./
COPY --from=build /TC2-BBS-mesh/requirements.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir --break-system-packages -r requirements.txt

# Define config volume
VOLUME /home/mesh/bbs/config
WORKDIR /home/mesh/bbs/config
COPY --from=build /TC2-BBS-mesh/example_config.ini ./config.ini
COPY --from=build /TC2-BBS-mesh/fortunes.txt ./

# Define the command to run
CMD ["sh", "-c", "python3 /home/mesh/bbs/server.py"]
