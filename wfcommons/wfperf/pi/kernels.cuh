#ifndef __KERNELS_CUH__
#define __KERNELS_CUH__

#include <curand_kernel.h>

#define COMPUTE_PI // if this line is uncommented then we compute PI (reduction etc)

#define NB_BLOCKS_X  16
#define NB_THREADS_X 16

__global__ void setup_kernel(curandState *state);
__global__ void monte_carlo_kernel(curandState *state, int *d_count, int m);

#endif

