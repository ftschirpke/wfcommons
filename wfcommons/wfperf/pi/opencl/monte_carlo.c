/**
 * Copyright (c) 2022. Loïc Pottier <lpottier@isi.edu>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#if __APPLE__
#include <OpenCL/opencl.h>
#elif __linux__ || __unix__
#include <CL/cl.h> /* on OLCF might be -> #include <CL/opencl.h> */
#endif

#define BUF_SIZE_INFO 128
#define BUF_SIZE_ERR 512
#define VENDOR "AMD"

#define NB_BLOCKS_X  16
#define NB_THREADS_X 16

//#define ARRAY_SIZE 1060634624 /* 8092 MB, max size is about 8192 MB on my GPU */
#define KERNEL_FILE "kernel.cl"
#define KERNEL_FUNC "monte_carlo"

#define CHECK_ERROR(x, func) do { \
  int retval = (x); \
  char msg[BUF_SIZE_ERR]; \
  cl_perror(retval, msg); \
  if (retval != CL_SUCCESS) { \
    fprintf(stderr, "[ERROR][%s:%d/%s()] %s\n", __FILE__, __LINE__, func, msg); \
    free(devices); \
    return EXIT_FAILURE; \
  } \
} while (0)

void print_info_device(cl_device_id);
cl_program build_program(cl_context, cl_device_id, const char*);
/* Helper function for translating OpenCL error codes */
void cl_perror(cl_int, char*);

int main(int argc, char** argv) {

    if (argc != 2) {
        fprintf(stderr, "Usage: %s <work (# 1M samples)>\n", argv[0]);
        exit(1);
    }

    int work = atoi(argv[1]);
    /* making into M samples */
    int m = 1000000*work;
    
    unsigned int n = NB_BLOCKS_X*NB_THREADS_X;

    char buf[BUF_SIZE_INFO];
    cl_int err;
    cl_platform_id platform;
    cl_uint num_devices;
    cl_device_id* devices = NULL;
    cl_device_id gpu_device = 0;

    cl_context context = 0;
    cl_program program = 0;
    cl_kernel kernel = 0;
    cl_command_queue command_queue = 0;
    cl_event kern_event = 0;
    cl_ulong time_start = 0;
    cl_ulong time_end = 0;

    /* Data and buffers */
    size_t local_size, global_size;
    unsigned long long* state = NULL;
    cl_mem d_state;
    
    // state = (unsigned long long*) calloc(sizeof(unsigned long long), n);

    // srand(SEED);
    // /* Initialize input with random seeds */
    // for(cl_uint i = 0; i < n; i++) {
    //     state[i] = rand();
    // }

    /* Number of work items in each local work group */
    // local_size = 1;
    // // Number of total work items - local_size must be divisor 
    // global_size = ceil(ARRAY_SIZE / (double) local_size) * local_size;

    global_size = NB_BLOCKS_X;
    local_size = NB_THREADS_X;

    printf("=== Sample=%d n=%d Global size=%zu, local_size=%zu ===\n", m, n, global_size, local_size);

    err = clGetPlatformIDs(1, &platform, NULL);
    CHECK_ERROR(err, "clGetPlatformIDs");

    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 0, NULL, &num_devices);
    CHECK_ERROR(err, "clGetDeviceIDs");

    devices = (cl_device_id*) calloc(sizeof(cl_device_id), num_devices);
    err = clGetDeviceIDs(NULL, CL_DEVICE_TYPE_GPU, num_devices, devices, NULL);
    CHECK_ERROR(err, "clGetDeviceIDs");

    for (cl_uint i = 0; i < num_devices; i++) {
        clGetDeviceInfo(devices[i], CL_DEVICE_VENDOR, BUF_SIZE_INFO, buf, NULL);
        if (strcmp(VENDOR, buf) == 0) {
            gpu_device = devices[i];
            break;
        }
    }
    
    /* Print information about the first AMD GPU we select */
    print_info_device(gpu_device);

    /* Creating context for one GPU */
    context = clCreateContext(NULL, 1, &gpu_device, NULL, NULL, &err);
    CHECK_ERROR(err, "clCreateContext");

    /* Build program */
    program = build_program(context, gpu_device, KERNEL_FILE);

    /* Creating the queue for that context */
    command_queue = clCreateCommandQueue(context, gpu_device, CL_QUEUE_PROFILING_ENABLE, &err);
    CHECK_ERROR(err, "clCreateCommandQueue");

    /* Input read-only */
    d_state = clCreateBuffer(context, CL_MEM_READ_ONLY, n*sizeof(unsigned long long), NULL, &err);
    CHECK_ERROR(err, "clCreateBuffer");

    // /* Output write-only */
    // d_output = clCreateBuffer(context, CL_MEM_READ_WRITE, ARRAY_SIZE*sizeof(double), NULL, &err);
    // CHECK_ERROR(err, "clCreateBuffer");

    /* Create a kernel */
    kernel = clCreateKernel(program, KERNEL_FUNC, &err);
    if(err < 0) {
        perror("Couldn't create a kernel");
        exit(1);
    };

    // /* Write our data set into the input array in device memory */
    // err = clEnqueueWriteBuffer(command_queue, d_state, CL_TRUE, 0, n*sizeof(unsigned long long), state, 0, NULL, NULL);
    // CHECK_ERROR(err, "clEnqueueWriteBuffer");

    /* Create kernel arguments */
    // err = clSetKernelArg(kernel, 0, sizeof(cl_mem), &d_output);
    // CHECK_ERROR(err, "clSetKernelArg");
    // err = clSetKernelArg(kernel, 0, sizeof(cl_mem), &d_state);
    // CHECK_ERROR(err, "clSetKernelArg");
    // err = clSetKernelArg(kernel, 1, local_size * sizeof(int), NULL);
    // CHECK_ERROR(err, "clSetKernelArg");
    err = clSetKernelArg(kernel, 0, sizeof(int), &m);
    CHECK_ERROR(err, "clSetKernelArg");

    /* 
        Enqueue kernel 
        At this point, the application has created all the data structures 
        (device, kernel, program, command queue, and context) needed by an 
        OpenCL host application. Now, it deploys the kernel to a device.
        Of the OpenCL functions that run on the host, clEnqueueNDRangeKernel 
        is probably the most important to understand. Not only does it deploy 
        kernels to devices, it also identifies how many work-items should 
        be generated to execute the kernel (global_size) and the number of 
        work-items in each work-group (local_size).
    */
    err = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL, &global_size, 
            &local_size, 0, NULL, &kern_event); 
    if(err < 0) {
        perror("Couldn't enqueue the kernel");
        exit(1);
    }

    /* wait kernel to finish */
    clWaitForEvents(1, &kern_event);
    clFinish(command_queue);

    /* Bring back the kernel's output */
    // err = clEnqueueReadBuffer(command_queue, d_output, CL_TRUE, 0, ARRAY_SIZE*sizeof(double), h_output, 0, NULL, NULL);
    // if(err < 0) {
    //     perror("Couldn't read the buffer");
    //     exit(1);
    // }

    /* Get execution time of the kernel */
    clGetEventProfilingInfo(kern_event, CL_PROFILING_COMMAND_START, sizeof(time_start), &time_start, NULL);
    clGetEventProfilingInfo(kern_event, CL_PROFILING_COMMAND_END, sizeof(time_end), &time_end, NULL);

    // /* Check result */
    // for(size_t i = 0; i < ARRAY_SIZE; i++) {
    //     printf("%.1f.\n", h_input[i]);
    // }

    printf("Execution time is: %0.3f milliseconds\n", (time_end-time_start) / 1000000.0);

    /* De-allocate resources */
    err = clReleaseKernel(kernel);
    CHECK_ERROR(err, "clReleaseKernel");

    // err = clReleaseMemObject(d_state);
    // CHECK_ERROR(err, "clReleaseMemObject");

    err = clReleaseCommandQueue(command_queue);
    CHECK_ERROR(err, "clReleaseCommandQueue");

    err = clReleaseProgram(program);
    CHECK_ERROR(err, "clReleaseProgram");

    err = clReleaseContext(context);
    CHECK_ERROR(err, "clReleaseContext");

    free(devices);
    // free(state);

    return EXIT_SUCCESS;
}

void print_info_device(cl_device_id dev) {
    char buf[BUF_SIZE_INFO];
    cl_uint compute_units;
    cl_ulong mem_size;
    /* Print information about the first AMD GPU we select */
    clGetDeviceInfo(dev, CL_DEVICE_NAME, BUF_SIZE_INFO, buf, NULL);
    fprintf(stdout, "Device : %s\n", buf);
    clGetDeviceInfo(dev, CL_DEVICE_VENDOR, BUF_SIZE_INFO, buf, NULL);
    fprintf(stdout, "  Vendor           : %s\n", buf);
    clGetDeviceInfo(dev, CL_DEVICE_VERSION, BUF_SIZE_INFO, buf, NULL);
    fprintf(stdout, "  Device version   : %s\n", buf);
    clGetDeviceInfo(dev, CL_DEVICE_MAX_COMPUTE_UNITS, sizeof(cl_uint), &compute_units, NULL);
    fprintf(stdout, "  Compute Units    : %d\n", compute_units);
    clGetDeviceInfo(dev, CL_DEVICE_GLOBAL_MEM_SIZE, sizeof(cl_ulong), &mem_size, NULL);
    fprintf(stdout, "  Available memory : %.2lf MB\n", mem_size / (1024.0*1024.0));
}

/* Create program from a file and compile it */
cl_program build_program(cl_context ctx, cl_device_id dev, const char* filename) {
    cl_program program;
    FILE *program_handle;
    char *program_buffer, *program_log;
    size_t program_size, log_size;
    int err;

    /* Read program file and place content into buffer */
    program_handle = fopen(filename, "r");
    if(!program_handle) {
        fprintf(stderr, "[ERROR][%s:%d/%s()] %s\n", __FILE__, __LINE__, "fopen", "Could not find the program file");
        exit(1);
    }

    fseek(program_handle, 0, SEEK_END);
    program_size = ftell(program_handle);
    rewind(program_handle);
    program_buffer = (char*) malloc(program_size + 1);
    program_buffer[program_size] = '\0';
    fread(program_buffer, sizeof(char), program_size, program_handle);
    fclose(program_handle);

    /* Create program from file */
    program = clCreateProgramWithSource(ctx, 1, (const char**) &program_buffer, &program_size, &err);
    free(program_buffer);
    if(err < 0) {
        fprintf(stderr, "[ERROR][%s:%d/%s()] %s\n", __FILE__, __LINE__, "clCreateProgramWithSource", "Could not create program");
        exit(1);
    }

    /*
    Build program 
    The fourth parameter accepts options that configure the compilation. 
    These are similar to the flags used by GCC. For example, you can 
    define a macro with the option -DMACRO=VALUE and turn off optimization 
    with -cl-opt-disable.
    */
    err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
    if(err < 0) {
        /* Find size of log and print to std output */
        clGetProgramBuildInfo(program, dev, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);
        program_log = (char*) malloc(log_size + 1);
        program_log[log_size] = '\0';
        clGetProgramBuildInfo(program, dev, CL_PROGRAM_BUILD_LOG, log_size + 1, program_log, NULL);
        fprintf(stderr, "[ERROR][%s:%d/%s()] %s\n", __FILE__, __LINE__, "clBuildProgram", program_log);
        free(program_log);
        fprintf(stderr, "Exiting..\n");
        exit(1);
    }

    return program;
}

void cl_perror(cl_int err, char* err_msg) {
    if (!err_msg) {
        return;
    }

    memset(err_msg, 0, BUF_SIZE_ERR);
    
    switch(err) {
        case CL_SUCCESS:
            strlcpy(err_msg, "Success.", BUF_SIZE_ERR);
        case CL_INVALID_CONTEXT:
            strlcpy(err_msg, "context is not a valid context.", BUF_SIZE_ERR);
        case CL_INVALID_DEVICE:
            strlcpy(err_msg, "device is not a valid device or is not associated with context.", BUF_SIZE_ERR);
        case CL_INVALID_VALUE:
            strlcpy(err_msg, "values specified in properties are not valid.", BUF_SIZE_ERR);
        case CL_INVALID_QUEUE_PROPERTIES:
            strlcpy(err_msg, "values specified in properties are valid but are not supported by the device.", BUF_SIZE_ERR);
        case CL_OUT_OF_HOST_MEMORY:
            strlcpy(err_msg, "there is a failure to allocate resources required by the OpenCL implementation on the host.", BUF_SIZE_ERR);
        case CL_INVALID_PLATFORM:
            strlcpy(err_msg, "properties is NULL and no platform could be selected or if platform value specified in properties is not a valid platform.", BUF_SIZE_ERR);
        case CL_DEVICE_NOT_AVAILABLE:
            strlcpy(err_msg, "a device in devices is currently not available even though the device was returned by clGetDeviceIDs.", BUF_SIZE_ERR);
        case CL_DEVICE_NOT_FOUND:
            strlcpy(err_msg, "no devices that match device_type were found.", BUF_SIZE_ERR);
        case CL_INVALID_BUFFER_SIZE:
            strlcpy(err_msg, "size is 0 or is greater than CL_DEVICE_MAX_MEM_ALLOC_SIZE value specified in table of OpenCL Device Queries for clGetDeviceInfo for all devices in context.", BUF_SIZE_ERR);
        case CL_INVALID_HOST_PTR:
            strlcpy(err_msg, "host_ptr is NULL and CL_MEM_USE_HOST_PTR or CL_MEM_COPY_HOST_PTR are set in flags or if host_ptr is not NULL but CL_MEM_COPY_HOST_PTR or CL_MEM_USE_HOST_PTR are not set in flags.", BUF_SIZE_ERR);
        case CL_MEM_OBJECT_ALLOCATION_FAILURE:
            strlcpy(err_msg, "there is a failure to allocate memory for buffer object.", BUF_SIZE_ERR);
        case CL_INVALID_KERNEL:
            strlcpy(err_msg, "kernel is not a valid kernel object.", BUF_SIZE_ERR);
        case CL_INVALID_ARG_INDEX:
            strlcpy(err_msg, "arg_index is not a valid argument index.", BUF_SIZE_ERR);
        case CL_INVALID_ARG_VALUE:
            strlcpy(err_msg, "arg_value specified is NULL for an argument that is not declared with the __local qualifier or vice-versa.", BUF_SIZE_ERR);
        case CL_INVALID_MEM_OBJECT:
            strlcpy(err_msg, "an argument declared to be a memory object when the specified arg_value is not a valid memory object.", BUF_SIZE_ERR);
        case CL_INVALID_SAMPLER:
            strlcpy(err_msg, "an argument declared to be of type sampler_t when the specified arg_value is not a valid sampler object.", BUF_SIZE_ERR);
        case CL_INVALID_ARG_SIZE:
            strlcpy(err_msg, "arg_size does not match the size of the data type for an argument that is not a memory object or if the argument is a memory object and arg_size != sizeof(cl_mem) or if arg_size is zero and the argument is declared with the __local qualifier or if the argument is a sampler and arg_size != sizeof(cl_sampler).", BUF_SIZE_ERR);
        default:
            strlcpy(err_msg, "Unknown error code.", BUF_SIZE_ERR);
    }
}

