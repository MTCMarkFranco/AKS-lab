FROM ubuntu:latest

RUN apt-get update && apt-get upgrade -y

CMD ["bash", "-c", "date"]