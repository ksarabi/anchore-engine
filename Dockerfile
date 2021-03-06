FROM ubuntu:18.04 as wheelbuilder
ARG CLI_COMMIT
LABEL anchore_cli_commit=$CLI_COMMIT
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV GOPATH=/go
RUN mkdir -p /go && \
    apt -y update && \
    apt -y install vim curl psmisc git rpm python3 python3-pip golang btrfs-tools git-core libdevmapper-dev libgpgme11-dev go-md2man libglib2.0-dev libostree-dev && \
    git clone https://github.com/containers/skopeo $GOPATH/src/github.com/containers/skopeo && \
    cd $GOPATH/src/github.com/containers/skopeo && \
    make binary-local-static DISABLE_CGO=1 && \
    make install
COPY . /anchore-engine
RUN pip3 install --upgrade pip
#   pip3 install --upgrade setuptools wheel

#RUN pip3 install -e git+git://github.com/anchore/anchore-cli.git@$CLI_COMMIT\#egg=anchorecli
COPY . /anchore-engine
WORKDIR /anchore-engine
RUN pip3 wheel --wheel-dir=/wheels -r requirements.txt

# Do the final build
FROM ubuntu:18.04
ARG CLI_COMMIT
ARG ANCHORE_COMMIT
LABEL anchore_cli_commit=$CLI_COMMIT
LABEL anchore_commit=$ANCHORE_COMMIT
ENV LANG=en_US.UTF-8
ENV LC_ALL=C.UTF-8
EXPOSE 8228 8338 8087 8082
RUN apt -y update && \
    apt -y install git curl psmisc rpm python3-minimal python3-pip && \
    pip3 install -e git+git://github.com/anchore/anchore-cli.git@$CLI_COMMIT\#egg=anchorecli && \
    apt -y remove git && \
    apt -y autoremove
COPY --from=wheelbuilder /wheels /wheels
COPY . /anchore-engine
COPY --from=wheelbuilder /usr/bin/skopeo /usr/bin/skopeo
COPY --from=wheelbuilder /etc/containers/policy.json /etc/containers/policy.json
WORKDIR /anchore-engine
RUN pip3 install --no-index --find-links=/wheels -r requirements.txt && pip3 install .
ENTRYPOINT ["/usr/local/bin/anchore-manager"]
CMD ["service", "start"]
