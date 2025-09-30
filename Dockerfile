
FROM amd64/ubuntu:noble

# install useful stuff
RUN apt-get update
RUN apt-get -y install pkg-config 
RUN apt-get -y install curl
RUN apt-get -y install git
RUN apt-get -y install wget 
RUN apt-get -y install make 
RUN apt-get -y install cmake 
RUN apt-get -y install cmake-data 
RUN apt-get -y install sudo 
RUN apt-get -y install vim --fix-missing
RUN apt-get -y install gcc 
RUN apt-get -y install gcc-multilib

# Python stuff
RUN apt-get -y install python3 python3-pip
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1
RUN pip install --break-system-packages pathos pandas filelock 
RUN pip install --break-system-packages networkx scipy matplotlib
RUN pip install --break-system-packages pyyaml jsonschema requests

# Stress-ng
RUN apt-get -y install stress-ng

COPY bin/* /usr/bin/
