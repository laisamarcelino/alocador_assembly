# ======================================================================
# Alocador de Memória em Assembly x86_64 (Traduzido do programa em C)
# ======================================================================

# ------------------------- Seção de Dados ----------------------------
.section .data
    # Variáveis globais equivalentes à versão em C:
    topoInicialHeap: .quad 0    # void* topoInicialHeap
    topoHeap:        .quad 0    # void* topoHeap
    listaLivres:     .quad 0    # Bloco* listaLivres
    listaOcupados:   .quad 0    # Bloco* listaOcupados

    vazio_str:    .string "<vazio>"  # Mensagem para heap vazio

    # Estrutura do cabeçalho (equivale ao struct Bloco em C):
    #   ocupado:4   (int)     - 1=ocupado, 0=livre
    #   tamanho:8   (size_t)  - tamanho solicitado
    #   prox:4      (ponteiro) - próximo bloco na lista
.set TAM_CABECALHO, 16  # Tamanho total do cabeçalho (4+8+4=16 bytes)

# ------------------------- Seção de Código ---------------------------
.section .text
.global iniciaAlocador, alocaMem, liberaMem, imprimeMapa, finalizaAlocador

# ======================= iniciaAlocador ==============================
# void iniciaAlocador()
# Inicializa o alocador obtendo o endereço inicial do heap
# ---------------------------------------------------------------------

iniciaAlocador:
    movq $0, %rdi          # Solicita o endereço atual do break
    call sbrk              # Chama sbrk(0)
    test %rax, %rax        # Verifica se sbrk falhou
    js .erro_init          # Salta se erro (retorno negativo)

    # Inicializa variáveis globais:
    movq %rax, topoInicialHeap(%rip)  # topoInicialHeap = sbrk(0)
    movq %rax, topoHeap(%rip)         # topoHeap = sbrk(0)
    movq $0, listaLivres(%rip)        # listaLivres = NULL
    movq $0, listaOcupados(%rip)      # listaOcupados = NULL
    ret

.erro_init:
    movq $0, %rax          # Retorna NULL em caso de erro
    ret

# ======================== alocaMem ===================================
# void* alocaMem(size_t num_bytes)
# Aloca bloco de memória do tamanho solicitado
# ---------------------------------------------------------------------

alocaMem:
    push %rbp              # Prólogo padrão
    mov %rsp, %rbp
    push %rbx              # Salva registradores preservados
    push %r12              
    push %r13              

    # Argumento num_bytes está em %rdi
    mov %rdi, %r12         # Guarda num_bytes em r12
    mov listaLivres(%rip), %r13  # atual = listaLivres

.busca_livre:
    test %r13, %r13        # Verifica se atual == NULL
    je .aloca_heap         # Se não há blocos livres, aloca novo

    # Verifica se bloco atual é grande o suficiente:
    movq 4(%r13), %rax     # atual->tamanho (offset 4)
    cmp %r12, %rax         # Compara com tamanho solicitado
    jb .proximo_bloco      # Salta se atual->tamanho < num_bytes

    # Bloco livre adequado encontrado:
    movl $1, 0(%r13)       # Marca como ocupado (atual->ocupado = 1)

    # Remove da lista de livres:
    mov %r13, %rsi         # bloco atual
    leaq listaLivres(%rip), %rdi  # &listaLivres
    call removeDaLista

    # Adiciona à lista de ocupados:
    mov %r13, %rsi
    leaq listaOcupados(%rip), %rdi
    call insereNaLista

    # Retorna ponteiro após o cabeçalho:
    leaq TAM_CABECALHO(%r13), %rax  # return (void*)(atual + 1)
    jmp .fim_aloca

.proximo_bloco:
    movq 12(%r13), %r13    # atual = atual->prox (offset 12)
    jmp .busca_livre       # Continua busca

.aloca_heap:
    # Calcula tamanho total necessário (alinhado em 16 bytes):
    mov %r12, %rax         # num_bytes
    add $15, %rax          # Arredonda para cima
    and $-16, %rax         # Alinha em 16 bytes
    mov %rax, %rbx         # Guarda tamanho alinhado dos dados
    add $TAM_CABECALHO, %rax # Adiciona tamanho do cabeçalho
    
    # Solicita memória ao SO:
    mov %rax, %rdi         # tamanho total
    call sbrk
    cmp $-1, %rax          # Verifica erro
    je .erro               # Salta se sbrk falhou

    # Inicializa cabeçalho do novo bloco:
    mov topoHeap(%rip), %r13  # endereço do novo bloco
    movl $1, (%r13)        # novo->ocupado = 1
    mov %r12, 4(%r13)      # novo->tamanho = num_bytes (tamanho original)
    movl $0, 12(%r13)      # novo->prox = NULL
    
    # Atualiza topoHeap:
    mov topoHeap(%rip), %rdi
    add $TAM_CABECALHO, %rdi  # Pula cabeçalho
    add %rbx, %rdi            # Adiciona tamanho dos dados
    mov %rdi, topoHeap(%rip)  # Atualiza global
    
    # Adiciona à lista de ocupados:
    mov %r13, %rsi
    leaq listaOcupados(%rip), %rdi
    call insereNaLista
    
    # Retorna ponteiro após o cabeçalho:
    leaq TAM_CABECALHO(%r13), %rax  # return (void*)(novo + 1)
    jmp .fim_aloca

.erro:
    mov $0, %rax           # Retorna NULL em caso de erro

.fim_aloca:
    pop %r13               # Restaura registradores
    pop %r12
    pop %rbx
    pop %rbp
    ret

# ======================= removeDaLista ==============================
# void removeDaLista(Bloco** lista, Bloco* alvo)
# Remove bloco alvo da lista especificada
# ---------------------------------------------------------------------

removeDaLista:
    push %rbp
    mov %rsp, %rbp

    # %rdi = &lista, %rsi = alvo

    # Verifica ponteiros NULL:
    movq (%rdi), %rax      # *lista
    test %rax, %rax        # if (*lista == NULL)
    je .retorna
    test %rsi, %rsi        # if (alvo == NULL)
    je .retorna

    # Verifica se alvo está no início da lista:
    cmp %rsi, %rax         # if (*lista == alvo)
    jne .busca_loop

    # Remove do início:
    movq 12(%rsi), %rdx    # alvo->prox
    movq %rdx, (%rdi)      # *lista = alvo->prox
    jmp .retorna

.busca_loop:
    movq (%rdi), %rcx      # p = *lista

.loop:
    movq 12(%rcx), %rax    # p->prox
    test %rax, %rax        # if (p->prox == NULL)
    je .retorna            # Fim da lista
    cmp %rsi, %rax         # if (p->prox == alvo)
    je .ajusta_prox
    movq %rax, %rcx        # p = p->prox
    jmp .loop

.ajusta_prox:
    movq 12(%rsi), %rdx    # alvo->prox
    movq %rdx, 12(%rcx)    # p->prox = alvo->prox

.retorna:
    pop %rbp
    ret

# ======================= insereNaLista ==============================
# void insereNaLista(Bloco** lista, Bloco* b)
# Insere bloco no início da lista especificada
# ---------------------------------------------------------------------

insereNaLista:
    push %rbp
    mov %rsp, %rbp

    # %rdi = &lista, %rsi = b

    movq (%rdi), %rax      # *lista
    movq %rax, 12(%rsi)    # b->prox = *lista
    movq %rsi, (%rdi)      # *lista = b

    pop %rbp
    ret

# ======================== liberaMem =================================
# int liberaMem(void* bloco)
# Libera bloco de memória alocado
# ---------------------------------------------------------------------

liberaMem:
    push %rbp
    mov %rsp, %rbp
    push %rbx              # Salva registradores
    push %r12
    push %r13
    push %r14
    push %r15

    # Verifica ponteiro NULL:
    test %rdi, %rdi        # if (bloco == NULL)
    jz .erro_libera           

    # Obtém cabeçalho do bloco:
    leaq -TAM_CABECALHO(%rdi), %rbx  # b = (Bloco*)bloco - 1
    
    # Verifica se cabeçalho está dentro dos limites do heap:
    movq topoInicialHeap(%rip), %rax
    cmp %rax, %rbx         # if (b < topoInicialHeap)
    jb .erro_libera
    
    movq topoHeap(%rip), %rax
    cmp %rax, %rbx         # if (b >= topoHeap)
    jae .erro_libera

    # Marca como livre:
    movl $0, (%rbx)        # b->ocupado = 0

    # Remove da lista de ocupados:
    mov %rbx, %rsi
    leaq listaOcupados(%rip), %rdi
    call removeDaLista

    # Adiciona à lista de livres:
    mov %rbx, %rsi
    leaq listaLivres(%rip), %rdi
    call insereNaLista

    # Coalesce com próximo bloco se estiver livre:
    movq 4(%rbx), %rax     # b->tamanho
    add $15, %rax          # Arredonda para cima
    and $-16, %rax         # Alinha
    leaq TAM_CABECALHO(%rbx, %rax), %r12  # próximo = (Bloco*)((char*)b + sizeof(Bloco) + b->tamanho)
    
    # Verifica se próximo está dentro do heap:
    movq topoHeap(%rip), %r13
    cmp %r13, %r12         # if (próximo >= topoHeap)
    jae .coalesce_anterior
    
    # Verifica se próximo está livre:
    cmpl $0, (%r12)        # if (próximo->ocupado != 0)
    jne .coalesce_anterior
    
    # Remove próximo da lista de livres:
    mov %r12, %rsi
    leaq listaLivres(%rip), %rdi
    call removeDaLista
    
    # Junta os blocos:
    movq 4(%r12), %rax     # próximo->tamanho
    add $15, %rax          # Arredonda para cima
    and $-16, %rax         # Alinha
    addq $TAM_CABECALHO, %rax  # Adiciona tamanho do cabeçalho
    addq %rax, 4(%rbx)     # b->tamanho += sizeof(Bloco) + próximo->tamanho

.coalesce_anterior:
    # Procura bloco anterior adjacente na lista de livres:
    movq listaLivres(%rip), %r14  # atual = listaLivres
    
.loop_anterior:
    test %r14, %r14        # if (atual == NULL)
    jz .verifica_todos_livres
    
    # Calcula fim do bloco atual:
    movq 4(%r14), %rax     # atual->tamanho
    add $15, %rax          # Arredonda para cima
    and $-16, %rax         # Alinha
    leaq TAM_CABECALHO(%r14, %rax), %rdx  # fim = (char*)atual + sizeof(Bloco) + atual->tamanho
    
    cmp %rdx, %rbx         # if (fim == b)
    je .encontrou_anterior
    
    movq 12(%r14), %r14    # atual = atual->prox
    jmp .loop_anterior

.encontrou_anterior:
    # Remove bloco atual da lista de livres:
    mov %rbx, %rsi
    leaq listaLivres(%rip), %rdi
    call removeDaLista
    
    # Junta com anterior:
    movq 4(%rbx), %rax     # b->tamanho
    add $15, %rax          # Arredonda para cima
    and $-16, %rax         # Alinha
    addq $TAM_CABECALHO, %rax  # Adiciona tamanho do cabeçalho
    addq %rax, 4(%r14)     # atual->tamanho += sizeof(Bloco) + b->tamanho

.verifica_todos_livres:
    # Se não há blocos ocupados, reseta o heap:
    movq listaOcupados(%rip), %rax
    test %rax, %rax        # if (listaOcupados == NULL)
    jnz .fim_libera_ok
    
    movq $0, listaLivres(%rip)  # listaLivres = NULL
    movq topoInicialHeap(%rip), %rdi
    movq %rdi, topoHeap(%rip)   # topoHeap = topoInicialHeap
    call brk                    # Reseta ponto de break

.fim_libera_ok:
    xor %eax, %eax         # Retorna 0 (sucesso)
    jmp .fim_libera

.erro_libera:
    mov $1, %eax           # Retorna 1 (erro)

.fim_libera:
    pop %r15               # Restaura registradores
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    pop %rbp
    ret

# ======================= imprimeMapa ================================
# void imprimeMapa()
# Imprime visualização do mapa de memória
# ---------------------------------------------------------------------

imprimeMapa:
    push %rbp
    mov %rsp, %rbp
    push %r12              # Salva registradores
    push %r13
    push %r14
    push %r15

    # Verifica se heap foi inicializado:
    movq topoInicialHeap(%rip), %rax
    test %rax, %rax        # if (topoInicialHeap == NULL)
    je .heap_vazio
    
    movq topoHeap(%rip), %rbx
    cmp %rax, %rbx         # if (topoHeap == topoInicialHeap)
    je .heap_vazio

    # Heap contém blocos:
    jmp .nao_vazio

.heap_vazio:
    # Imprime "<vazio>\n":
    mov $1, %rax           # sys_write
    mov $1, %rdi           # stdout
    leaq vazio_str(%rip), %rsi  # "<vazio>"
    mov $7, %rdx           # comprimento
    syscall
    
    # Imprime nova linha:
    mov $1, %rax
    mov $1, %rdi
    mov $10, %r14          # '\n'
    push %r14              # Armazena na stack
    mov %rsp, %rsi         # Ponteiro para '\n'
    mov $1, %rdx           # 1 byte
    syscall
    add $8, %rsp           # Limpa stack
    jmp .fim_imprime_func

.nao_vazio:
    movq topoInicialHeap(%rip), %r12  # atual = topoInicialHeap

.loop_bloco:
    movq topoHeap(%rip), %r13
    cmp %r13, %r12         # while (atual < topoHeap)
    jae .fim_imprime

    # Imprime cabeçalho (como caracteres '#'):
    mov $TAM_CABECALHO, %r15  # sizeof(Bloco)

.loop_hash:
    test %r15, %r15        # for (i=0; i<sizeof(Bloco); i++)
    jz .depois_hash
    
    mov $1, %rax           # sys_write
    mov $1, %rdi           # stdout
    mov $35, %r14          # '#'
    push %r14
    mov %rsp, %rsi         # Ponteiro para '#'
    mov $1, %rdx           # 1 byte
    syscall
    add $8, %rsp
    
    dec %r15
    jmp .loop_hash

.depois_hash:
    # Determina caractere de status:
    movl (%r12), %eax      # atual->ocupado
    test %eax, %eax        # if (ocupado)
    je .usa_menos
    mov $43, %r14          # '+' para ocupado (alterado de '*' original)
    jmp .print_dados

.usa_menos:
    mov $45, %r14          # '-' para livre

.print_dados:
    # Imprime área de dados:
    movq 4(%r12), %r15     # atual->tamanho

.loop_dados:
    test %r15, %r15        # for (i=0; i<tamanho; i++)
    jz .avanca_bloco
    
    mov $1, %rax           # sys_write
    mov $1, %rdi           # stdout
    push %r14              # '+' ou '-'
    mov %rsp, %rsi         # Ponteiro para char
    mov $1, %rdx           # 1 byte
    syscall
    add $8, %rsp
    
    dec %r15
    jmp .loop_dados

.avanca_bloco:
    # Avança para próximo bloco:
    movq 4(%r12), %rax     # atual->tamanho
    add $15, %rax          # Arredonda para cima
    and $-16, %rax         # Alinha
    add $TAM_CABECALHO, %rax  # Adiciona tamanho do cabeçalho
    add %rax, %r12         # atual = (char*)atual + tamanho_total
    jmp .loop_bloco

.fim_imprime:
    # Imprime nova linha:
    mov $1, %rax
    mov $1, %rdi
    mov $10, %r14          # '\n'
    push %r14
    mov %rsp, %rsi
    mov $1, %rdx
    syscall
    add $8, %rsp

.fim_imprime_func:
    pop %r15               # Restaura registradores
    pop %r14
    pop %r13
    pop %r12
    pop %rbp
    ret

# ===================== finalizaAlocador =============================
# void finalizaAlocador()
# Reseta o alocador e libera toda a memória
# ---------------------------------------------------------------------

finalizaAlocador:
    push %rbp
    mov %rsp, %rbp

    # Reseta heap para posição inicial:
    movq topoInicialHeap(%rip), %rdi
    call brk

    # Reseta todas as variáveis globais:
    movq $0, topoInicialHeap(%rip)
    movq $0, topoHeap(%rip)
    movq $0, listaLivres(%rip)
    movq $0, listaOcupados(%rip)

    pop %rbp
    ret

    