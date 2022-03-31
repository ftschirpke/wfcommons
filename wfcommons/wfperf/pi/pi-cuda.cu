#include <iostream>
#include <iomanip>
#include <chrono>
#include <thread>
#include <curand.h>
#include <ctime>
#include <cmath>
#include "kernels.cuh"

double PI = 3.1415926535897932384626433832795028841971693993751058209749445923;

int main(int argc, char** argv)
{
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <work (# 1M samples)>\n";
        exit(1);
    }

    unsigned int n = NB_BLOCKS_X*NB_THREADS_X*NB_BLOCKS_X*NB_THREADS_X;
    unsigned int m;
    unsigned int work;
    #ifdef COMPUTE_PI
    int *h_count;
    #endif
    int *d_count;
    curandState *d_state;

    int numdevices;
    int numprocs;
    int grid_dim_x;
    int grid_dim_y;
    int grid_dim_z;
    int block_dim_x;
    int block_dim_y;
    int block_dim_z;
    int max_thread_block;
    int current_id;

    //checking the user input for work
    try {
        work = std::stoi(argv[1]);
    } catch (std::invalid_argument &e) {
        std::cerr << "Invalid argument: " << e.what() << "\n";
        exit(1);
    }
    
    cudaGetDeviceCount(&numdevices);
    cudaGetDevice(&current_id);

    cudaDeviceGetAttribute(&numprocs, cudaDevAttrMultiProcessorCount, current_id);
    cudaDeviceGetAttribute(&max_thread_block, cudaDevAttrMaxThreadsPerBlock, current_id);
    cudaDeviceGetAttribute(&grid_dim_x, cudaDevAttrMaxBlockDimX, current_id);
    cudaDeviceGetAttribute(&grid_dim_y, cudaDevAttrMaxBlockDimY, current_id);
    cudaDeviceGetAttribute(&grid_dim_z, cudaDevAttrMaxBlockDimZ, current_id);
    cudaDeviceGetAttribute(&block_dim_x, cudaDevAttrMaxGridDimX, current_id);
    cudaDeviceGetAttribute(&block_dim_y, cudaDevAttrMaxGridDimY, current_id);
    cudaDeviceGetAttribute(&block_dim_z, cudaDevAttrMaxGridDimZ, current_id);

    std::cout << "Number of GPUs: " << numdevices << std::endl;
    std::cout << "Current GPU ID: " << current_id << std::endl;
    std::cout << "   Number of multiprocessors: " << numprocs << std::endl;
    std::cout << "   Grid max size: (" << grid_dim_x << "," << grid_dim_y << "," << grid_dim_z << ")"  << std::endl;
    std::cout << "   Block max size: (" << block_dim_x << "," << block_dim_y << "," << block_dim_z << ")"  << std::endl;
    std::cout << "   Max thread per blocks: " << max_thread_block << std::endl;

    // set up timing stuff
    float gpu_elapsed_time;
    cudaEvent_t gpu_start, gpu_stop;
    cudaEventCreate(&gpu_start);
    cudaEventCreate(&gpu_stop);
    cudaEventRecord(gpu_start, 0);

    //making into M samples
    m = 1000000*work;
    // allocate memory
    #ifdef COMPUTE_PI
    h_count = (int*)malloc(n*sizeof(int));
    #endif
    cudaMalloc((void**)&d_count, NB_BLOCKS_X*sizeof(int));
    cudaMalloc((void**)&d_state, n*sizeof(curandState));
    cudaMemset(d_count, 0, sizeof(int));

    // set kernel
    dim3 gridSize(NB_BLOCKS_X,1,1);
    dim3 blockSize(NB_THREADS_X,1,1);

    setup_kernel<<< gridSize, blockSize>>>(d_state);
    // monte carlo kernel
    monte_carlo_kernel<<<gridSize, blockSize>>>(d_state, d_count, m);

    // // copy results back to the host
    #ifdef COMPUTE_PI
    cudaMemcpy(h_count, d_count, NB_BLOCKS_X*sizeof(int), cudaMemcpyDeviceToHost);
    #endif
    cudaEventRecord(gpu_stop, 0);
    cudaEventSynchronize(gpu_stop);
    cudaEventElapsedTime(&gpu_elapsed_time, gpu_start, gpu_stop);
    cudaEventDestroy(gpu_start);
    cudaEventDestroy(gpu_stop);

    #ifdef COMPUTE_PI
    // display results and timings for gpu
    double pi = 0.0;
    for (int i = 0; i < NB_BLOCKS_X; i++) {
        pi += (double) h_count[i];
    }
    pi = 4.0*pi/(m*NB_BLOCKS_X*NB_THREADS_X);
    std::cout << "Approximate pi calculated on GPU is: " << pi << std::setprecision(6) << " (relative error: " << fabs((PI-pi)/PI) << ")" << std::endl;
    #endif
    
    std::cout << std::setprecision(6) << "GPU stress test is over and it took " << gpu_elapsed_time/1000.0 << " seconds" << std::endl;

    // delete memory
    #ifdef COMPUTE_PI
    free(h_count);
    #endif
    cudaFree(d_count);
    cudaFree(d_state);
}

