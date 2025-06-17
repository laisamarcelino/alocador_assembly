#ifndef MEU_ALOCADOR_H
#define MEU_ALOCADOR_H

#include <stdio.h>

void iniciaAlocador();
void* alocaMem(int num_bytes);
void liberaMem(void *ptr);
void imprimeMapa();
void finalizaAlocador();

#endif
