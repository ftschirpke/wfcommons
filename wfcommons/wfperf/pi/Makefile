#Makefile 
#define variables
objects= pi-cuda.o kernels.o 
NVCC= nvcc               #cuda c compiler
opt= -O2                 #optimization flag
LIBS=  
execname= pi-cuda


#compile
$(execname): $(objects)
	$(NVCC) $(opt) -o $(execname) $(objects) $(LIBS) 

kernels.o: kernels.cu
	$(NVCC) $(opt)  -c kernels.cu
pi-cuda.o: pi-cuda.cu
	$(NVCC) $(opt)  -c pi-cuda.cu


#clean Makefile
clean:
	rm $(objects)
#end of Makefile