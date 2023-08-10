FROM python:3-bookworm

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install stress-ng
RUN apt-get -y install psmisc

RUN mkdir -p /wfcommons
WORKDIR /wfcommons

COPY wfcommons/wfbench/requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

COPY wfcommons/wfbench/wfbench.py /usr/local/bin/wfbench.py
COPY bin bin
COPY bin/cpu-benchmark.cpp bin/cpu-benchmark.cpp
RUN g++ -std=c++11 bin/cpu-benchmark.cpp -o bin/cpu-benchmark
RUN cp bin/cpu-benchmark /usr/local/bin/cpu-benchmark
