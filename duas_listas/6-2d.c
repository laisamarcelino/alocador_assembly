#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>

typedef struct bloco {
    int ocupado;                // 0 = livre, 1 = ocupado
    size_t tamanho;             // tamanho da área de dados
    struct bloco* prox;        // próximo na lista
} Bloco;

// Ponteiros globais para heap e listas
void* topoInicialHeap = NULL;
void* topoHeap = NULL;

Bloco* listaLivres = NULL;
Bloco* listaOcupados = NULL;

// Inicializa o alocador
void iniciaAlocador() {
    void* atual = sbrk(0);      //pega o topo atual da heap
    topoInicialHeap = atual;
    topoHeap = atual;
    listaLivres = NULL;
    listaOcupados = NULL;
}

// Finaliza o alocador (libera memória para o estado inicial)
void finalizaAlocador() {
    sbrk((intptr_t)topoInicialHeap - (intptr_t)sbrk(0));
    topoHeap = topoInicialHeap;
    listaLivres = NULL;
    listaOcupados = NULL;
}

// Função auxiliar: remove bloco de uma lista encadeada
void removeDaLista(Bloco** lista, Bloco* alvo) {
    if (!*lista || !alvo) return;

    if (*lista == alvo) {
        *lista = alvo->prox;
        return;
    }

    Bloco* atual = *lista;
    while (atual->prox && atual->prox != alvo)
        atual = atual->prox;

    if (atual->prox == alvo)
        atual->prox = alvo->prox;
}

// Função auxiliar: insere bloco no início de uma lista
void adicionaNaLista(Bloco** lista, Bloco* bloco) {
    bloco->prox = *lista;
    *lista = bloco;
}

// Aloca memória com pelo menos 'num_bytes'
void* alocaMem(int num_bytes) {
    Bloco* atual = listaLivres;

    while (atual) {
        if (atual->tamanho >= (size_t)num_bytes) {
            removeDaLista(&listaLivres, atual);
            atual->ocupado = 1;
            adicionaNaLista(&listaOcupados, atual);
            return (void*)(atual + 1);
        }
        atual = atual->prox;
    }

    // Se não encontrou bloco livre, solicita novo espaço ao sistema
    size_t total = sizeof(Bloco) + num_bytes;
    Bloco* novo = (Bloco*)topoHeap;

    if (sbrk(total) == (void*)-1) return NULL;

    novo->ocupado = 1;
    novo->tamanho = num_bytes;
    novo->prox = NULL;

    topoHeap = (void*)((char*)topoHeap + total);

    adicionaNaLista(&listaOcupados, novo);
    return (void*)(novo + 1);
}

// Libera memória e tenta coalescer com blocos adjacentes
int liberaMem(void* ptr) {
    if (!ptr) return 1;

    Bloco* bloco = ((Bloco*)ptr) - 1;
    bloco->ocupado = 0;

    removeDaLista(&listaOcupados, bloco);

    // Coalesce com próximo
    Bloco* proximo = (Bloco*)((char*)bloco + sizeof(Bloco) + bloco->tamanho);
    if ((void*)proximo < topoHeap && proximo->ocupado == 0) {
        removeDaLista(&listaLivres, proximo);
        bloco->tamanho += sizeof(Bloco) + proximo->tamanho;
    }

    // Coalesce com anterior
    Bloco* atual = listaLivres;
    while (atual) {
        Bloco* fimAtual = (Bloco*)((char*)atual + sizeof(Bloco) + atual->tamanho);
        if (fimAtual == bloco) {
            atual->tamanho += sizeof(Bloco) + bloco->tamanho;
            return 0;
        }
        atual = atual->prox;
    }

    adicionaNaLista(&listaLivres, bloco);
    return 0;
}

// Imprime o mapa de memória com '#' para cabeçalhos e '+/-' para dados
void imprimeMapa() {
    Bloco* atual = (Bloco*)topoInicialHeap;
    if (atual == topoHeap) {
        printf("<vazio>\n");
        return;
    }

    while ((void*)atual < topoHeap) {
        for (int i = 0; i < sizeof(Bloco); i++) 
            printf("#");

        char simbolo = atual->ocupado ? '+' : '-';
        for (size_t i = 0; i < atual->tamanho; i++) 
            printf("%c", simbolo);

        atual = (Bloco*)((char*)atual + sizeof(Bloco) + atual->tamanho);
    }

    printf("\n");
}
int main (long int argc, char** argv) {
    void *a, *b;
  
    iniciaAlocador();               // Impressão esperada
    imprimeMapa();                  // <vazio>

    a = (void *) alocaMem(10);
    imprimeMapa();                    // ################**********
    b = (void *) alocaMem(4);
    imprimeMapa();                  // ################**********##############****
    liberaMem(a);
    imprimeMapa();                  // ################----------##############****
    liberaMem(b);                   // ################----------------------------
    imprimeMapa();                                // ou
                                    // <vazio>
                                    
    finalizaAlocador();
  }