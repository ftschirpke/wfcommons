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
#define BUF_SIZE_ERR 1024
#define VENDOR "AMD"

#define SEED 123456789
#define COMPUTE_PI

/* WARNING: WORK_ITEMS must divide WORK_GROUPS */
#define WORK_GROUPS  16
#define WORK_ITEMS 8

#define KERNEL_FILE "kernel.cl"
#define KERNEL_FUNC "monte_carlo"

double PI = 3.1415926535897932384626433832795028841971693993751058209749445923;

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

    if (WORK_GROUPS % WORK_ITEMS != 0) {
        fprintf(stderr, "Number of work groups does not divide the number of work items\n");
        exit(1);
    }

    int work = atoi(argv[1]);
    /* making into M samples */
    int m = 1000000*work;
    
    unsigned int n = WORK_GROUPS*WORK_ITEMS;

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
    size_t local_size, global_size, num_groups;
    unsigned long* state = NULL;
    unsigned int* h_output = NULL;
    cl_mem d_state, d_output;
    
    state = (unsigned long*) calloc(sizeof(unsigned long), n);

    srand(SEED);
    /* Initialize input with random seeds */
    for(cl_uint i = 0; i < n; i++) {
        state[i] = rand();
    }

    global_size = WORK_GROUPS;
    local_size = WORK_ITEMS;

    num_groups = global_size/local_size;
    h_output = (unsigned int*) calloc(sizeof(unsigned int), num_groups);

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
    d_state = clCreateBuffer(context, CL_MEM_READ_ONLY, n*sizeof(unsigned long), NULL, &err);
    CHECK_ERROR(err, "clCreateBuffer");

    /* Output write-only */
    d_output = clCreateBuffer(context, CL_MEM_READ_WRITE, num_groups*sizeof(unsigned int), NULL, &err);
    CHECK_ERROR(err, "clCreateBuffer");

    /* Create a kernel */
    kernel = clCreateKernel(program, KERNEL_FUNC, &err);
    if(err < 0) {
        perror("Couldn't create a kernel");
        exit(1);
    };

    /* Write our data set into the input array in device memory */
    err = clEnqueueWriteBuffer(command_queue, d_state, CL_TRUE, 0, n*sizeof(unsigned long long), state, 0, NULL, NULL);
    CHECK_ERROR(err, "clEnqueueWriteBuffer");

    /* Create kernel arguments */
    err = clSetKernelArg(kernel, 0, sizeof(cl_mem), &d_state);
    CHECK_ERROR(err, "clSetKernelArg");
    err = clSetKernelArg(kernel, 1, sizeof(cl_mem), &d_output);
    CHECK_ERROR(err, "clSetKernelArg");
    // err = clSetKernelArg(kernel, 1, local_size * sizeof(int), NULL);
    // CHECK_ERROR(err, "clSetKernelArg");
    err = clSetKernelArg(kernel, 2, sizeof(int), &m);
    CHECK_ERROR(err, "clSetKernelArg");

    /* Enqueue kernel */
    err = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL, &global_size, 
            &local_size, 0, NULL, &kern_event); 
    CHECK_ERROR(err, "clEnqueueNDRangeKernel");

    /* wait kernel to finish */
    clWaitForEvents(1, &kern_event);
    clFinish(command_queue);

    /* Bring back the kernel's output */
    err = clEnqueueReadBuffer(command_queue, d_output, CL_TRUE, 0, num_groups*sizeof(unsigned int), h_output, 0, NULL, NULL);
    if(err < 0) {
        perror("Couldn't read the buffer");
        exit(1);
    }

    /* Get execution time of the kernel */
    clGetEventProfilingInfo(kern_event, CL_PROFILING_COMMAND_START, sizeof(time_start), &time_start, NULL);
    clGetEventProfilingInfo(kern_event, CL_PROFILING_COMMAND_END, sizeof(time_end), &time_end, NULL);

    #ifdef COMPUTE_PI
    /* Check result */
    unsigned int total = 0;
    for(size_t i = 0; i < num_groups; i++) {
        total += h_output[i];
    }
    double pi = (double)4.0*total/(m*global_size);
    printf("Pi = %03f (relative error %03f)\n", pi, fabs((PI-pi)/PI));
    #endif

    printf("Execution time is: %.6f milliseconds\n", (time_end-time_start) / 1000000.0);

    /* De-allocate resources */
    err = clReleaseKernel(kernel);
    CHECK_ERROR(err, "clReleaseKernel");

    err = clReleaseMemObject(d_state);
    CHECK_ERROR(err, "clReleaseMemObject");

    err = clReleaseMemObject(d_output);
    CHECK_ERROR(err, "clReleaseMemObject");

    err = clReleaseCommandQueue(command_queue);
    CHECK_ERROR(err, "clReleaseCommandQueue");

    err = clReleaseProgram(program);
    CHECK_ERROR(err, "clReleaseProgram");

    err = clReleaseContext(context);
    CHECK_ERROR(err, "clReleaseContext");

    free(devices);
    free(state);
    free(h_output);

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
        case CL_INVALID_PROGRAM_EXECUTABLE:
            strlcpy(err_msg, "there is no successfully built program executable available for device associated with command_queue.", BUF_SIZE_ERR);
        case CL_INVALID_COMMAND_QUEUE:
            strlcpy(err_msg, "command_queue is not a valid command-queue.", BUF_SIZE_ERR);
        case CL_INVALID_CONTEXT:
            strlcpy(err_msg, "- context is not a valid context.\n- context associated with command_queue and kernel is not the same or if the context associated with command_queue and events in event_wait_list are not the same.", BUF_SIZE_ERR);
        case CL_INVALID_KERNEL_ARGS:
            strlcpy(err_msg, "the kernel argument values have not been specified.", BUF_SIZE_ERR);
        case CL_INVALID_WORK_DIMENSION:
            strlcpy(err_msg, "work_dim is not a valid value (i.e. a value between 1 and 3).", BUF_SIZE_ERR);
        case CL_INVALID_WORK_GROUP_SIZE:
            strlcpy(err_msg, "- local_work_size is specified and number of work-items specified by global_work_size is not evenly divisable by size of work-group given by local_work_size or does not match the work-group size specified for kernel using the __attribute__((reqd_work_group_size(X, Y, Z))) qualifier in program source.\n- local_work_size is specified and the total number of work-items in the work-group computed as local_work_size[0] *... local_work_size[work_dim - 1] is greater than the value specified by CL_DEVICE_MAX_WORK_GROUP_SIZE in the table of OpenCL Device Queries for clGetDeviceInfo.\n- local_work_size is NULL and the __attribute__((reqd_work_group_size(X, Y, Z))) qualifier is used to declare the work-group size for kernel in the program source.", BUF_SIZE_ERR);
        case CL_INVALID_WORK_ITEM_SIZE:
            strlcpy(err_msg, "the number of work-items specified in any of local_work_size[0], ... local_work_size[work_dim - 1] is greater than the corresponding values specified by CL_DEVICE_MAX_WORK_ITEM_SIZES[0], .... CL_DEVICE_MAX_WORK_ITEM_SIZES[work_dim - 1].", BUF_SIZE_ERR);
        case CL_INVALID_GLOBAL_OFFSET:
            strlcpy(err_msg, "global_work_offset is not NULL.", BUF_SIZE_ERR);
        case CL_OUT_OF_RESOURCES:
            strlcpy(err_msg, "there is a failure to queue the execution instance of kernel on the command-queue because of insufficient resources needed to execute the kernel. For example, the explicitly specified local_work_size causes a failure to execute the kernel because of insufficient resources such as registers or local memory. Another example would be the number of read-only image args used in kernel exceed the CL_DEVICE_MAX_READ_IMAGE_ARGS value for device or the number of write-only image args used in kernel exceed the CL_DEVICE_MAX_WRITE_IMAGE_ARGS value for device or the number of samplers used in kernel exceed CL_DEVICE_MAX_SAMPLERS for device.", BUF_SIZE_ERR);
        case CL_INVALID_EVENT_WAIT_LIST:
            strlcpy(err_msg, "event_wait_list is NULL and num_events_in_wait_list > 0, or event_wait_list is not NULL and num_events_in_wait_list is 0, or if event objects in event_wait_list are not valid events.", BUF_SIZE_ERR);
        default:
            strlcpy(err_msg, "Unknown error code.", BUF_SIZE_ERR);
    }
}

