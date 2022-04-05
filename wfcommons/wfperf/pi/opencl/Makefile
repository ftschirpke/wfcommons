CC=gcc
HOST=$(shell uname)
TARGET=monte_carlo
SRC=monte_carlo.c
KERN=kernel.cl
CFLAGS=-Wall -Wextra
OPT=-O2

ifeq ($(HOST), Linux)
LDFLAGS=-lOpenCL
endif
ifeq ($(HOST), Darwin)
LDFLAGS=-framework OpenCL
endif

all: $(TARGET)

$(TARGET): $(SRC) $(KERN)
	$(CC) $(CFLAGS) $(OPT) $(LDFLAGS) $(SRC) -o $(TARGET)

.PHONY: clean

clean:
	rm $(TARGET)
