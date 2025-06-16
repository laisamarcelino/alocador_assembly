.section .data
    topoInicialHeap: .quad 0            # valor origial de brk (antes das alocações)
    topoHeap: .quad 0                   # ponteiro para o fim da heap (atual brk)
    listaLivres: .quad 0
    listaOcupados: .quad 0
    format_str:     .string "%c"
    newline_str:    .string "\n"
    vazio_str:      .string "<vazio>\n"
    char_hash:      .byte '#'
    char_plus:      .byte '+'
    char_minus:     .byte '-'


.section .text
.globl iniciaAlocador
.globl finalizaAlocador
.globl removeDaLista
.globl adicionaNaLista
.globl alocaMem
.globl liberaMem
.globl imprimeMapa
.extern printf

# --------------------------------- iniciaAlocador -----------------------------------
iniciaAlocador:
    pushq %rbp                          # empilha (salva) %rbp
    movq %rsp, %rbp                     # faz %rbp apontar para novo R.A 

    movq $0, %rdi                       # argumento 0 para buscar o topo atual da heap
    movq $12, %rax                      # syscall numero 12 = brk
    syscall                             # executa a syscall

    movq %rax, topoInicialHeap(%rip)
    movq %rax, topoHeap(%rip)
    movq $0, listaLivres(%rip)
    movq $0, listaOcupados(%rip)

    popq %rbp                           # restaura %rbp
    ret                                 # retorna ao chamador


# --------------------------------- finalizaAlocador ----------------------------------
finalizaAlocador:
    pushq %rbp
    movq %rsp, %rbp
    movq $0, %rdi                       # argumento 0 para buscar o topo atual da heap
    movq $12, %rax                      # syscall numero 12 = brk
    syscall                             # executa a syscall

    movq topoInicialHeap(%rip), %rdi    # Redefine brk para o topo inicial
    movq $12, %rax
    syscall

    movq topoInicialHeap(%rip), %rsi
    movq %rsi, topoHeap(%rip)
    movq $0, listaLivres(%rip)
    movq $0, listaOcupados(%rip)

    popq %rbp
    ret

# --------------------------------- removeDaLista ----------------------------------
removeDaLista:
    pushq %rbp
    movq %rsp, %rbp
    
    # rdi = Bloco** lista
    # rsi = Bloco* alvo
    movq (%rdi), %rax          # rax = *lista
    
    cmpq $0, %rax              # if (*lista == NULL) return
    je fim_remove
    cmpq $0, %rsi              # if (alvo == NULL) return
    je fim_remove
    
    cmpq %rax, %rsi            # if (*lista == alvo)
    jne procura_remove
    
    # *lista = alvo->prox
    movq 16(%rsi), %rdx        # rdx = alvo->prox
    movq %rdx, (%rdi)
    jmp fim_remove

procura_remove:
    movq %rax, %rcx            # rcx = atual
    
loop_remove:
    movq 16(%rcx), %rdx        # rdx = atual->prox
    cmpq $0, %rdx              # if (atual->prox == NULL) break
    je fim_remove
    
    cmpq %rdx, %rsi            # if (atual->prox == alvo)
    jne continua_remove
    
    # atual->prox = alvo->prox
    movq 16(%rsi), %r8
    movq %r8, 16(%rcx)
    jmp fim_remove

continua_remove:
    movq %rdx, %rcx
    jmp loop_remove

fim_remove:
    popq %rbp
    ret


# --------------------------------- adiocionaNaLista ----------------------------------
adicionaNaLista:
    pushq %rbp
    movq %rsp, %rbp
    
    # rdi = Bloco** lista
    # rsi = Bloco* bloco
    
    movq (%rdi), %rax          # rax = *lista
    movq %rax, 16(%rsi)        # bloco->prox = *lista
    movq %rsi, (%rdi)          # *lista = bloco
    
    popq %rbp
    ret

# --------------------------------- alocaMem -----------------------------------
alocaMem:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13

    movq %rdi, %rbx             # %rbx = num_bytes
    movq listaLivres(%rip), %r12 # %r12 = atual (iterador)

procura_bloco_livre:
    cmpq $0, %r12               # if (atual == NULL)
    je aloca_novo_bloco

    # Verifica se o bloco livre tem tamanho suficiente
    movq 8(%r12), %r13         # %r13 = atual->tamanho
    cmpq %rbx, %r13
    jl proximo_bloco

    # Bloco adequado encontrado
    movl $1, (%r12)            # marca como ocupado
    movq %r12, %rdi            # arg1 = bloco
    leaq listaLivres(%rip), %rsi # arg2 = &listaLivres
    call removeDaLista

    movq %r12, %rdi            # arg1 = bloco
    leaq listaOcupados(%rip), %rsi # arg2 = &listaOcupados
    call adicionaNaLista

    leaq 24(%r12), %rax        # retorna ponteiro para área de dados (bloco + 24)
    jmp fim_aloca

proximo_bloco:
    movq 16(%r12), %r12        # atual = atual->prox
    jmp procura_bloco_livre

aloca_novo_bloco:
    # Calcula o tamanho total necessário (incluindo o cabeçalho do bloco)
    movq %rbx, %rdi            # rdi = num_bytes
    addq $24, %rdi             # rdi = tamanho total (bloco + dados)

    # Calcula novo topo da heap
    movq topoHeap(%rip), %rsi
    addq %rdi, %rsi            # rsi = novo topo

    # Chama syscall brk para aumentar a heap até o novo topo
    movq %rsi, %rdi            # argumento = novo topo
    movq $12, %rax             # syscall brk
    syscall

    # Verifica se brk falhou (retornou NULL ou valor anterior)
    cmpq %rax, %rsi
    jne erro_alocar            # se não conseguiu mover brk, erro

    # Agora podemos usar a memória entre topoHeap e novo topo
    movq topoHeap(%rip), %r12  # r12 = início do novo bloco
    movl $1, (%r12)            # bloco->ocupado = 1
    movq %rbx, 8(%r12)         # bloco->tamanho = num_bytes
    movq $0, 16(%r12)          # bloco->prox = NULL

    # Atualiza topoHeap
    movq %rsi, topoHeap(%rip)

    # Adiciona à lista de ocupados
    movq %r12, %rdi
    leaq listaOcupados(%rip), %rsi
    call adicionaNaLista

    # Retorna ponteiro para a área de dados (logo após o cabeçalho do bloco)
    leaq 24(%r12), %rax
    jmp fim_aloca

erro_alocar:
    movq $0, %rax              # retorna NULL

fim_aloca:
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret


# --------------------------------- liberaMem -----------------------------------
liberaMem:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13

    cmpq $0, %rdi              # if (ptr == NULL)
    je erro_liberacao

    # Recupera ponteiro para início do bloco
    movq %rdi, %rbx
    subq $24, %rbx             # bloco = ptr - sizeof(Bloco)

    # Marca como livre
    movl $0, (%rbx)

    # Remove da lista de ocupados
    movq %rbx, %rdi
    leaq listaOcupados(%rip), %rsi
    call removeDaLista

    # -------------------- Coalesce com próximo bloco --------------------
    movq 8(%rbx), %rax         # tamanho do bloco atual
    leaq 24(%rbx, %rax), %r12  # próximo bloco = atual + 24 + tamanho

    cmpq topoHeap(%rip), %r12  # se próximo bloco ultrapassa topo da heap, não tenta coalescer
    jge coalesce_anterior

    cmpl $0, (%r12)            # se próximo bloco está ocupado, não coalesce
    jne coalesce_anterior

    # Remove próximo da lista de livres (vamos fundi-lo ao atual)
    movq %r12, %rdi
    leaq listaLivres(%rip), %rsi
    call removeDaLista

    # Atualiza tamanho do bloco atual para incluir o próximo
    movq 8(%r12), %rax         # tamanho do próximo
    addq $24, %rax             # inclui cabeçalho
    addq %rax, 8(%rbx)         # novo tamanho do bloco atual

coalesce_anterior:
    # -------------------- Coalesce com bloco anterior (se adjacente) --------------------
    movq listaLivres(%rip), %r12
    movq $0, %r13              # r13 = anterior (NULL)

loop_anterior:
    cmpq $0, %r12
    je fim_coalesce            # fim da lista

    movq 8(%r12), %rax         # tamanho do bloco examinado
    leaq 24(%r12, %rax), %rdi  # fim do bloco atual
    cmpq %rdi, %rbx            # se fim == início do bloco liberado
    jne proximo_anterior

    # Bloco anterior adjacente encontrado
    movq %r12, %r13
    jmp coalesce

proximo_anterior:
    movq 16(%r12), %r12        # avança para próximo na lista
    jmp loop_anterior

coalesce:
    # Remove bloco atual da lista de livres (caso já tenha sido inserido)
    movq %rbx, %rdi
    leaq listaLivres(%rip), %rsi
    call removeDaLista

    # Junta bloco atual ao anterior (r13)
    movq 8(%rbx), %rax
    addq $24, %rax
    addq %rax, 8(%r13)

    # O bloco coalescido é o anterior
    movq %r13, %rbx

fim_coalesce:
    # Insere bloco (coalescido ou não) na lista de livres
    movq %rbx, %rdi
    leaq listaLivres(%rip), %rsi
    call adicionaNaLista

    movq $0, %rax              # sucesso
    jmp fim_libera

erro_liberacao:
    movq $1, %rax              # erro

fim_libera:
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret


imprimeMapa:
    pushq %rbp
    movq %rsp, %rbp

    movq topoInicialHeap(%rip), %rsi  # início da heap
    movq topoHeap(%rip), %rdi         # fim da heap

.loop_mapa:
    cmpq %rsi, %rdi
    jge .fim_mapa

    # Verifica se %rsi está dentro de algum bloco ocupado
    movq listaOcupados(%rip), %rbx
.procura_ocupado:
    cmpq $0, %rbx
    je .verifica_livre

    movq %rbx, %rax                # início do bloco
    movq 8(%rbx), %rcx             # tamanho
    addq $24, %rcx                 # tamanho total com cabeçalho
    leaq (%rbx, %rcx), %rdx        # fim do bloco

    cmpq %rsi, %rbx
    jb .verifica_meio_ocupado
    jmp .proximo_ocupado

.verifica_meio_ocupado:
    cmpq %rsi, %rdx
    jbe .proximo_ocupado

    # Está dentro de um bloco ocupado
    movzbl char_hash(%rip), %edi
    call printf
    incq %rsi
    jmp .loop_mapa

.proximo_ocupado:
    movq 16(%rbx), %rbx
    jmp .procura_ocupado

.verifica_livre:
    movq listaLivres(%rip), %rbx
.procura_livre:
    cmpq $0, %rbx
    je .imprime_traco

    movq %rbx, %rax
    movq 8(%rbx), %rcx
    addq $24, %rcx
    leaq (%rbx, %rcx), %rdx

    cmpq %rsi, %rbx
    jb .verifica_meio_livre
    jmp .proximo_livre

.verifica_meio_livre:
    cmpq %rsi, %rdx
    jbe .proximo_livre

    # Está dentro de um bloco livre
    movzbl char_plus(%rip), %edi
    call printf
    incq %rsi
    jmp .loop_mapa

.proximo_livre:
    movq 16(%rbx), %rbx
    jmp .procura_livre

.imprime_traco:
    movzbl char_minus(%rip), %edi
    call printf
    incq %rsi
    jmp .loop_mapa

.fim_mapa:
    # imprime \n
    movq $newline_str, %rdi
    call printf

    popq %rbp
    ret
