FROM rakudo-star

LABEL maintainer="tobi oetiker" \
      description="jsonHound example runner"

COPY . /opt
WORKDIR /opt
RUN zef --debug --deps-only install .
