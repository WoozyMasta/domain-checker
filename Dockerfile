FROM docker.io/alpine:3.15

# hadolint ignore=DL3018
RUN apk add --no-cache bash coreutils grep bind-tools whois pv && \
    printf '%s\n' google foo bar nonexistentdomain > words.txt

COPY domain-checker.sh /domain-checker

ENTRYPOINT ["./domain-checker"]
