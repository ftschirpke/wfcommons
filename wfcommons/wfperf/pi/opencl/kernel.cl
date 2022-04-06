/**
 * Copyright (c) 2022. Loïc Pottier <lpottier@isi.edu>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#define WORK_ITEMS 8
#define COMPUTE_PI

/* 
 * As OpenCL does not have random generators we have to come up with ours.
 * A C code which implements a version of the random 
 * number generator (RNG) used by the NAS Parallel Benchmarks.
 * The generator has the form:
 *     X(K+1) = A * X(K) mod 2^46
 * where the suggested value of the multiplier A is 5^13 = 1220703125.
 * This scheme generates 2^44 numbers before repeating.
 */

__kernel void monte_carlo(__global unsigned long* state, __global unsigned int* count, int m) {
   int threadx = get_local_id(0);
   unsigned int tid = get_global_id(0);

   __local int in_circle[WORK_ITEMS];
   in_circle[threadx] = 0;

   unsigned long div = 70368744177664; // 2^46

   int temp = 0;

   unsigned long curr_state_x = state[tid];
   unsigned long curr_state_y = state[tid]+1373;
   unsigned long new_state_x, new_state_y;

   while(temp < m) {

      new_state_x = (1220703125 * curr_state_x ) % div;
      double x = new_state_x / (double) div;

      new_state_y = (1220703125 * curr_state_y ) % div;
      double y = new_state_y / (double) div;

      curr_state_x = new_state_x;
      curr_state_y = new_state_y;

      if (x*x + y*y <= 1.0f) {
         in_circle[threadx]++;
      }
      temp++;
   }

   barrier(CLK_LOCAL_MEM_FENCE | CLK_GLOBAL_MEM_FENCE);
   // printf("[Item %2d/%2d] %.5f\n", get_local_id(0)+1, get_local_size(0), 4.0*in_circle[threadx]/(double)m);

   #ifdef COMPUTE_PI
   /* Reduction */
   for(int i = 1; i < get_local_size(0); i *= 2) {
      // printf("[Item %2d/%2d] %.5f\n", get_local_id(0)+1, get_local_size(0), 4.0*in_circle[threadx]/(double)m);
      if (threadx % (i*2) == 0) {
         in_circle[threadx] += in_circle[threadx+i];
      }
      barrier(CLK_LOCAL_MEM_FENCE | CLK_GLOBAL_MEM_FENCE);
   }


   if(threadx == 0) {
      count[get_group_id(0)] = in_circle[threadx];
      // printf("(Group %2d/%2d) [Item %2d/%2d] %.5f\n", get_group_id(0)+1, get_num_groups(0), get_global_id(0)+1, get_global_size(0), 4.0*in_circle[threadx]/((double)m*get_local_size(0)) );
   }
   #endif
}

