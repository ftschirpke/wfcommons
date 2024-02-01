FROM ubuntu

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y python3 python3-pip stress-ng psmisc

RUN mkdir -p /wfcommons
WORKDIR /wfcommons

COPY requirements.txt /wfcommons/requirements.txt
RUN pip3 install -r requirements.txt
COPY wfbench.py /usr/local/bin/wfbench.py

COPY bin/ /usr/local/bin/
RUN ls -lisah /usr/local/bin/
RUN g++ -std=c++11 /usr/local/bin/cpu-benchmark.cpp -o /usr/local/bin/cpu-benchmark
