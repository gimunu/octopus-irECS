/*
** Copyright (C) 2010-2012 X. Andrade <xavier@tddft.org>
** 
** FortranCL is free software: you can redistribute it and/or modify
** it under the terms of the GNU Lesser General Public License as published by
** the Free Software Foundation, either version 3 of the License, or
** (at your option) any later version.
**
** FortranCL is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU Lesser General Public License for more details.
**
** You should have received a copy of the GNU Lesser General Public License
** along with this program.  If not, see <http://www.gnu.org/licenses/>.
**
** $Id: cl_platform_low.c 12359 2014-08-06 18:49:59Z dstrubbe $
*/

#include <config.h>
#include "localcl.h"

#include <string_f.h>


void FC_FUNC_(clgetplatformids_num, CLGETPLATFORMIDS_NUM)(int * num_platforms, int * status){
  cl_uint ret_platform;

  *status = (int) clGetPlatformIDs(0, NULL, &ret_platform);
  *num_platforms = (int) ret_platform;
}


/* -----------------------------------------------------------------------*/

void FC_FUNC_(clgetplatformids_listall, CLGETPLATFORMIDS_LISTALL)
     (const int * num_entries, cl_platform_id * platforms, int * num_platforms, int * status){

  cl_uint unum_platforms;

  *status = (int) clGetPlatformIDs((cl_uint) *num_entries, platforms, &unum_platforms);
  *num_platforms = (int) unum_platforms;
}

/* -----------------------------------------------------------------------*/

void FC_FUNC_(clgetplatforminfo_str, CLGETPLATFORMINFO_STR)
     (const cl_platform_id * platform, const int * param_name, STR_F_TYPE param_value, int * status STR_ARG1){
  char info[2048];

  *status = (int) clGetPlatformInfo(*platform, (cl_platform_info) *param_name, sizeof(info), info, NULL);

  TO_F_STR1(info, param_value);
}




