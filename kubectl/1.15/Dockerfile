FROM alpine:3.10

COPY sync.sh /sync.sh

RUN apk --no-cache add \
    bash \
    curl \
    jq \
    && curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl

