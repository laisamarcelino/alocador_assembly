#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>

// Estrutura do bloco
typedef struct bloco {
    int ocupado;                // 0 = livre, 1 = ocupado
    size_t tamanho;             // tamanho do bloco de dados
} Bloco;

// Variaveis globais
void* topoInicialHeap = NULL;   //valor origial de brk (antes das alocações)
Bloco* inicio_heap = NULL;      //endereço do primeiro bloco da lista
void* topo_heap = NULL;         //ponteiro para o fim da heap (atual brk)

void iniciaAlocador(){
    void* atual = sbrk(0);      //pega o topo atual da heap
    topoInicialHeap = atual;
    topo_heap = atual;
    inicio_heap = NULL;
}  

void finalizaAlocador(){
    sbrk((intptr_t)topoInicialHeap - (intptr_t)sbrk(0)); // volta ao topo original
    inicio_heap = NULL;
    topo_heap = topoInicialHeap;
}

/* 6.1
// indica que o bloco está livre.
int liberaMem(void* bloco){
    if (bloco == NULL) 
        return 1;

    Bloco* cabecalho = ((Bloco*)bloco) - 1;
    cabecalho->ocupado = 0;

    // Se todos estiverem livres, podemos zerar a heap (opcional)
    Bloco* atual = inicio_heap;
    int todos_livres = 1;
    while ((void*)atual < topo_heap) {
        if (atual->ocupado) {
            todos_livres = 0;
            break;
        }
        atual = (Bloco*)((char*)atual + sizeof(Bloco) + atual->tamanho);
    }

    if (todos_livres) {
        inicio_heap = NULL;
    }

    return 0;
}
*/
// 6.2a
int liberaMem(void* bloco){
    if (bloco == NULL) 
        return 1;

    Bloco* cabecalho = ((Bloco*)bloco) - 1;
    cabecalho->ocupado = 0;

    // --- 1) Coalesce com o próximo ---  
    Bloco* proximo = (Bloco*)((char*)cabecalho + sizeof(Bloco) + cabecalho->tamanho);
    if ((void*)proximo < topo_heap && proximo->ocupado == 0) {
        // aumenta o tamanho do bloco atual para engolir o próximo
        cabecalho->tamanho += sizeof(Bloco) + proximo->tamanho;
    }

    // --- 2) Coalesce com o anterior ---  
    // Para achar o bloco anterior, varremos a lista desde inicio_heap
    Bloco* p = inicio_heap;
    Bloco* anterior = NULL;
    while ((void*)p < (void*)cabecalho) {
        Bloco* next = (Bloco*)((char*)p + sizeof(Bloco) + p->tamanho);
        if (next == cabecalho) {
            anterior = p;
            break;
        }
        p = next;
    }
    // Se existir e estiver livre, mescla
    if (anterior != NULL && anterior->ocupado == 0) {
        anterior->tamanho += sizeof(Bloco) + cabecalho->tamanho;
        cabecalho = anterior;  // agora o bloco “atual” passa a ser o anterior
    }

    // --- 3) Se tudo for livre, zera a lista ---  
    Bloco* iter = inicio_heap;
    int todos_livres = 1;
    while ((void*)iter < topo_heap) {
        if (iter->ocupado) {
            todos_livres = 0;
            break;
        }
        iter = (Bloco*)((char*)iter + sizeof(Bloco) + iter->tamanho);
    }
    if (todos_livres) {
        inicio_heap = NULL;
    }

    return 0;
}

void* alocaMem(int num_bytes){
    // 1) reaproveita bloco livre, se existir
    if (inicio_heap != NULL) {
        Bloco* p = inicio_heap;
        while ((void*)p < topo_heap) {
            if (!p->ocupado && p->tamanho >= num_bytes) {
                p->ocupado = 1;
                return (void*)(p + 1);
            }
            p = (Bloco*)((char*)(p + 1) + p->tamanho);
        }
    }

    // 2) senão, aloca novo bloco no topo
    size_t total_bytes = sizeof(Bloco) + num_bytes;
    Bloco* novo_bloco = (Bloco*)topo_heap;
    if (sbrk(total_bytes) == (void*)-1)
        return NULL;

    novo_bloco->ocupado = 1;
    novo_bloco->tamanho = num_bytes;

    if (inicio_heap == NULL) {
        inicio_heap = novo_bloco;
    }

    topo_heap = (void*)((char*)topo_heap + total_bytes);
    return (void*)(novo_bloco + 1);
}

       
void imprimeMapa(){
    if (inicio_heap == NULL) {
        printf("<vazio>\n");
        return;
    }

    Bloco* atual = inicio_heap;
    while ((void*)atual < topo_heap) {
        for (int i = 0; i < sizeof(Bloco); i++) {
            printf("#");
        }

        char simbolo = atual->ocupado ? '+' : '-';
        for (size_t i = 0; i < atual->tamanho; i++) {
            printf("%c", simbolo);
        }

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


