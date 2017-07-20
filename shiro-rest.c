/*
  SHIRO
  ===
  Copyright (c) 2017 Kanru Hua. All rights reserved.

  This file is part of SHIRO.

  SHIRO is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  SHIRO is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with SHIRO.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <getopt.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "external/cJSON/cJSON.h"
#include "external/liblrhsmm/common.h"
#include "external/liblrhsmm/estimate.h"
#include "external/liblrhsmm/serial.h"

#include "cli-common.h"

static void print_usage() {
  fprintf(stderr,
    "shiro-rest\n"
    "  -m model-file\n"
    "  -s segmentation-file\n"
    "  -n num-iteration\n"
    "  -g (use geometric duration distribution)\n"
    "  -h (print usage)\n");
  exit(1);
}

extern char* optarg;
int main(int argc, char** argv) {
  int c;
  cJSON* j_segm = NULL;
  lrh_model* hsmm = NULL;

  //lrh_inference_stprune = 15;
  //lrh_inference_stprune_full_slope = 0.5;

  int opt_niter = 1;
  int opt_geodur = 0;
  while((c = getopt(argc, argv, "m:s:n:gh")) != -1) {
    char* jsonstr = NULL;
    switch(c) {
    case 'm':
      hsmm = load_model(optarg);
      if(hsmm == NULL) {
        fprintf(stderr, "Error: failed to load model from %s\n", optarg);
        return 1;
      }
    break;
    case 's':
      jsonstr = readall(optarg);
      if(jsonstr == NULL) {
        fprintf(stderr, "Error: cannot open %s.\n", optarg);
        return 1;
      }
      j_segm = cJSON_Parse(jsonstr);
      if(j_segm == NULL) {
        fprintf(stderr, "Error: failed to parse %s.\n", optarg);
        return 1;
      }
      free(jsonstr);
    break;
    case 'n':
      opt_niter = atoi(optarg);
    break;
    case 'g':
      opt_geodur = 1;
    break;
    case 'h':
      print_usage();
    break;
    default:
      abort();
    }
  }
  if(j_segm == NULL) {
    fprintf(stderr, "Error: segmentation file is not specified.\n");
    return 1;
  }
  if(hsmm == NULL) {
    fprintf(stderr, "Error: model file is not specified.\n");
    return 1;
  }

  cJSON* j_file_list = cJSON_GetObjectItem(j_segm, "file_list");
  checkvar(file_list);
  int nfile = cJSON_GetArraySize(j_file_list);

  for(int iter = 0; iter < opt_niter; iter ++) {
    fprintf(stderr, "Running iteration %d/%d...\n", iter, opt_niter);
    FP_TYPE total_lh = 0;

    lrh_model_stat* hstat = lrh_model_stat_from_model(hsmm);
    lrh_model_precompute(hsmm);
    for(int f = 0; f < nfile; f ++) {
      cJSON* j_file_list_f = cJSON_GetArrayItem(j_file_list, f);
      cJSON* j_filename = cJSON_GetObjectItem(j_file_list_f, "filename");
      checkvar(filename);
      cJSON* j_states = cJSON_GetObjectItem(j_file_list_f, "states");
      checkvar(states);

      lrh_observ* o = load_observ_from_float(j_filename -> valuestring, hsmm);
      lrh_seg* s = load_seg_from_json(j_states, hsmm -> nstream);
      for(int i = 0; i < s -> nseg; i ++)
        if(s -> time[i] > o -> nt)
          s -> time[i] = o -> nt;

      if(opt_geodur)
        total_lh += lrh_estimate_geometric(hstat, hsmm, o, s);
      else
        total_lh += lrh_estimate(hstat, hsmm, o, s);

      lrh_delete_seg(s);
      lrh_delete_observ(o);
    }

    if(opt_geodur)
      lrh_model_update(hsmm, hstat, 1);
    else
      lrh_model_update(hsmm, hstat, 0);
    lrh_delete_model_stat(hstat);

    fprintf(stderr, "Average log likelihood = %f.\n", total_lh / nfile);
  }

  cmp_ctx_t cmpobj;
  cmp_init(& cmpobj, stdout, file_reader, file_writer);
  lrh_write_model(& cmpobj, hsmm);

  cJSON_Delete(j_segm);
  lrh_delete_model(hsmm);
  return 0;
}