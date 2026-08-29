FROM alpine:3.20
RUN apk add --no-cache bash curl jq git subversion
COPY seed.sh /usr/local/bin/seed.sh
RUN chmod +x /usr/local/bin/seed.sh
ENTRYPOINT ["/usr/local/bin/seed.sh"]
