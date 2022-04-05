/**
 * Copyright (c) 2022. Loïc Pottier <lpottier@isi.edu>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#define NB_THREADS_X 16
#define SEED 123456789

/* 
 * A C code which implements a version of the random 
 * number generator (RNG) used by the NAS Parallel Benchmarks.
 * The generator has the form:
 *     X(K+1) = A * X(K) mod 2^46
 * where the suggested value of the multiplier A is 5^13 = 1220703125.
 * This scheme generates 2^44 numbers before repeating.
 */

__kernel void monte_carlo(int m) {
   int threadx = get_local_id(0);
   unsigned int tid = get_global_id(0);
   // unsigned int index_y = get_global_id(1);

   __local int in_circle[NB_THREADS_X];
   in_circle[threadx] = 0;

   unsigned long div = 70368744177664; // 2^46

   int temp = 0;

   unsigned long curr_state_x = 987654321;
   unsigned long curr_state_y = 123456789;
   unsigned long new_state_x, new_state_y;

   while(temp < m) {

      new_state_x = (1220703125 * curr_state_x ) % div;
      double x = new_state_x / (double) div;

      new_state_y = (1220703125 * curr_state_y ) % div;
      double y = new_state_y / (double) div;

      curr_state_x = new_state_x;
      curr_state_y = new_state_y;

      // printf("[%u] %f %f => %f\n", temp, x, y, x*x + y*y);
      if (x*x + y*y <= 1.0f) {
         in_circle[threadx]++;
      }
      temp++;

   }

   // Barrier(CLK_LOCAL_MEM_FENCE);

   printf("[%u, %u] %f\n", tid, threadx, in_circle[threadx]/ (double)m);

}

