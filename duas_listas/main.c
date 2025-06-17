#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>

typedef struct bloco {
    int ocupado;
    size_t tamanho;
    struct bloco* prox;
} Bloco;

// Ponteiros globais
void* topoInicialHeap = NULL;
void* topoHeap = NULL;
Bloco* listaLivres = NULL;
Bloco* listaOcupados = NULL;

void iniciaAlocador() {
    void* atual = sbrk(0);
    topoInicialHeap = atual;
    topoHeap = atual;
    listaLivres = NULL;
    listaOcupados = NULL;
}

void finalizaAlocador() {
    sbrk((intptr_t)topoInicialHeap - (intptr_t)sbrk(0));
    topoHeap = topoInicialHeap;
    listaLivres = NULL;
    listaOcupados = NULL;
}

void removeDaLista(Bloco** lista, Bloco* alvo) {
    if (*lista == NULL || alvo == NULL) return;

    if (*lista == alvo) {
        *lista = alvo->prox;
        return;
    }

    Bloco* p = *lista;
    while (p->prox && p->prox != alvo)
        p = p->prox;

    if (p->prox == alvo)
        p->prox = alvo->prox;
}

void insereNaLista(Bloco** lista, Bloco* b) {
    b->prox = *lista;
    *lista = b;
}

void* alocaMem(int num_bytes) {
    Bloco* atual = listaLivres;
    Bloco* anterior = NULL;

    // Busca bloco livre adequado
    while (atual) {
        if (atual->tamanho >= (size_t)num_bytes) {
            atual->ocupado = 1;
            removeDaLista(&listaLivres, atual);
            insereNaLista(&listaOcupados, atual);
            return (void*)(atual + 1);
        }
        anterior = atual;
        atual = atual->prox;
    }

    // Aloca novo bloco
    size_t total = sizeof(Bloco) + num_bytes;
    Bloco* novo = (Bloco*)topoHeap;

    if (sbrk(total) == (void*)-1)
        return NULL;

    novo->ocupado = 1;
    novo->tamanho = num_bytes;
    novo->prox = NULL;

    topoHeap = (void*)((char*)topoHeap + total);
    insereNaLista(&listaOcupados, novo);
    return (void*)(novo + 1);
}

int liberaMem(void* bloco) {
    if (bloco == NULL)
        return 1;

    Bloco* b = ((Bloco*)bloco) - 1;
    b->ocupado = 0;

    removeDaLista(&listaOcupados, b);
    insereNaLista(&listaLivres, b);

    // Coalesce com próximo
    Bloco* proximo = (Bloco*)((char*)b + sizeof(Bloco) + b->tamanho);
    if ((void*)proximo < topoHeap && proximo->ocupado == 0) {
        removeDaLista(&listaLivres, proximo);
        b->tamanho += sizeof(Bloco) + proximo->tamanho;
    }

    // Coalesce com anterior (procura pelo início da heap)
    Bloco* anterior = NULL;
    Bloco* atual = listaLivres;
    while (atual) {
        Bloco* next = (Bloco*)((char*)atual + sizeof(Bloco) + atual->tamanho);
        if (next == b) {
            anterior = atual;
            break;
        }
        atual = atual->prox;
    }

    if (anterior) {
        removeDaLista(&listaLivres, b);
        anterior->tamanho += sizeof(Bloco) + b->tamanho;
    }

    // Verifica se todos estão livres
    int todosLivres = 1;
    Bloco* cursor = listaOcupados;
    while (cursor) {
        todosLivres = 0;
        break;
    }

    if (todosLivres) {
        listaLivres = NULL;
    }

    return 0;
}

void imprimeMapa() {
    if (listaLivres == NULL && listaOcupados == NULL) {
        printf("<vazio>\n");
        return;
    }

    Bloco* atual = (Bloco*)topoInicialHeap;
    while ((void*)atual < topoHeap) {
        for (int i = 0; i < sizeof(Bloco); i++) printf("#");
        char c = atual->ocupado ? '+' : '-';
        for (size_t i = 0; i < atual->tamanho; i++) printf("%c", c);
        atual = (Bloco*)((char*)atual + sizeof(Bloco) + atual->tamanho);
    }
    printf("\n");
}

int main(long int argc, char** argv) {
    void *a, *b;

    iniciaAlocador();
    imprimeMapa();     // <vazio>

    a = alocaMem(10);
    imprimeMapa();     // ########################++++++++++

    b = alocaMem(4);
    imprimeMapa();     // ########################++++++++++########################++++

    liberaMem(a);
    imprimeMapa();     // ########################----------########################++++

    liberaMem(b);
    imprimeMapa();     // ########################----------------------------

    finalizaAlocador();
}
