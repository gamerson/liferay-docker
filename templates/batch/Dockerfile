FROM bash:latest

COPY resources/job.sh /batch/job.sh

RUN \
	apk add --no-cache curl jq tree && \
	chmod +x /batch/job.sh

WORKDIR /batch/

ENTRYPOINT ["/batch/job.sh"]