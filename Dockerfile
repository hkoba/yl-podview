FROM perl:5.38

COPY . /usr/src/myapp

WORKDIR /usr/src/myapp

RUN cpm install -g

CMD ["./run-plackup.sh"]
