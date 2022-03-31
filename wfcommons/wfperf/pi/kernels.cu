#include "kernels.cuh"
#include <stdio.h>

__global__ void setup_kernel(curandState *state)
{
	int index = threadIdx.x + blockDim.x * blockIdx.x;
    curand_init(123456789, index, 0, &state[index]);
}

__global__ void monte_carlo_kernel(curandState *state, int *d_count, int m)
{
	unsigned int index_x = threadIdx.x + blockDim.x*blockIdx.x;
	// unsigned int index_y = threadIdx.y + blockDim.y*blockIdx.y;
	
	__shared__ int inside_circle[NB_THREADS_X]; //Data shared per block
	inside_circle[threadIdx.x] = 0;
	
	unsigned int temp = 0;
	while(temp < m){
		float x = curand_uniform(&state[index_x]);
		float y = curand_uniform(&state[index_x]);
		if (x*x + y*y <= 1.0f) {
			inside_circle[threadIdx.x]++;
		}
		temp++;
	}

	#ifdef COMPUTE_PI
	// We actually compute Pi
	// Reduction on threads for each block
	for(int i = 1; i < blockDim.x; i *= 2) {
		if (threadIdx.x % (i*2) == 0) {
			inside_circle[threadIdx.x] += inside_circle[threadIdx.x + i];
		}
		__syncthreads();
	}

	// update to our global variable count for each block (done by thread 0)
	if(threadIdx.x == 0) {
		atomicAdd(d_count, inside_circle[0]);
	}
	#endif
}



