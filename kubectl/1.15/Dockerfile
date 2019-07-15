FROM alpine:3.10 AS downloader

RUN apk --no-cache add \
    curl \
    && curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl


FROM alpine:3.10
COPY --from=downloader /usr/local/bin/kubectl /usr/local/bin/

