//
//  mxo.h
//  MaXPCe
//
//  Created by Kota on 11/26/25.
//
// WIP
#include<stdlib.h>
#include<stdint.h>
typedef struct {
    
} mxo_t;
mxo_t * const dsp_new();
void mxo_free(mxo_t * const this);
void mxo_bang(mxo_t * const this, intptr_t const inlet);
void mxo_int(mxo_t * const this, intptr_t const inlet, intptr_t const value);
void mxo_float(mxo_t * const this, intptr_t const inlet, double const value);
