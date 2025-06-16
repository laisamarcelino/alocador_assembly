.section .data
    topoInicialHeap: .quad 0            # valor origial de brk (antes das alocações)
    inicioHeap: .quad 0                 # endereço do primeiro bloco da lista
    topoHeap: .quad 0                   # ponteiro para o fim da heap (atual brk)
    format_str:     .string "%c"
    newline_str:    .string "\n"
    vazio_str:      .string "<vazio>\n"
    char_hash:      .byte '#'
    char_plus:      .byte '+'
    char_minus:     .byte '-'

.section .text
.globl iniciaAlocador
.globl finalizaAlocador
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
    movq $0, inicioHeap(%rip)

    popq %rbp                           # restaura %rbp
    ret                                 # retorna ao chamador


# --------------------------------- finalizaAlocador ----------------------------------
finalizaAlocador:
    movq $0, %rdi                       # argumento 0 para buscar o topo atual da heap
    movq $12, %rax                      # syscall numero 12 = brk
    syscall                             # executa a syscall

    movq topoInicialHeap(%rip), %rdi    # Redefine brk para o topo inicial
    movq $12, %rax
    syscall

    movq $0, inicioHeap(%rip)

    movq topoInicialHeap(%rip), %rsi    # registrador intermediário
    movq %rsi, topoHeap(%rip)         
    ret


# --------------------------------- alocaMem -----------------------------------
alocaMem:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx                          # Salva %rbx para guardar num_bytes
    pushq %r12                          # Salva %r12 como iterador
    pushq %r13                          # Salva %r13 (tamanho necessário)

    movq %rdi, %rbx                     # %rbx = num_bytes (argumento)
    movq $0, %rax                       # %rax = NULL (retorna se falhar)

    # --- Fase 1: Procura bloco livre existente ---
    cmpq $0, inicioHeap(%rip)           # Verifica se a heap está vazia
    je alocaNovoBloco                   # Se vazia, aloca novo bloco

    movq inicioHeap(%rip), %r12         # %r12 = iterador (início da heap)

procuraBlocoLivre:
    cmpq topoHeap(%rip), %r12           # Verifica se chegou ao fim da heap
    jge alocaNovoBloco                  # Se sim, tenta alocar novo bloco

    # Verifica se bloco está livre e tem tamanho suficiente
    cmpl $0, (%r12)                     # Verifica se bloco está livre (ocupado == 0)
    jne proxBloco                       # Se ocupado, pula

    movq 8(%r12), %r13                  # %r13 = tamanho do bloco livre
    cmpq %rbx, %r13                     # Compara tamanho do bloco com num_bytes
    jl proxBloco                        # Se menor, não serve

    # Bloco adequado encontrado - marca como ocupado
    movl $1, (%r12)                     # Marca como ocupado
    leaq 16(%r12), %rax                 # Retorna ponteiro para área de dados (bloco + 16)
    jmp fimAlocaMem                     # Sai da função

proxBloco:
    # Avança para o próximo bloco
    movq 8(%r12), %r13                  # %r13 = tamanho do bloco atual
    leaq 16(%r12, %r13), %r12           # %r12 = próximo bloco (atual + 16 + tamanho)
    jmp procuraBlocoLivre

alocaNovoBloco:
    # --- Fase 2: Aloca novo bloco no topo da heap ---
    movq %rbx, %r13                     # %r13 = num_bytes
    addq $16, %r13                      # %r13 = num_bytes + sizeof(Bloco) (tamanho total)

    movq topoHeap(%rip), %rdi
    addq %r13, %rdi            # rdi = novo limite esperado da heap
    movq %rdi, %r15            # salva valor esperado
    movq $12, %rax
    syscall
    cmpq %r15, %rax
    jne fimAlocaMem            # se brk não mudou, houve erro

    # Configura novo bloco
    movq topoHeap(%rip), %r12           # %r12 = início do novo bloco
    movl $1, (%r12)                     # ocupado = 1
    movq %rbx, 8(%r12)                  # tamanho = num_bytes

    # Atualiza topoHeap e inicioHeap (se necessário)
    movq %rax, topoHeap(%rip)           # topoHeap = novo topo (retornado por brk)
    cmpq $0, inicioHeap(%rip)           # Verifica se inicioHeap é NULL
    jne naoAtualizaIni
    movq %r12, inicioHeap(%rip)         # inicioHeap = novo bloco (se heap estava vazia)

naoAtualizaIni:
    leaq 16(%r12), %rax                 # Retorna ponteiro para área de dados (bloco + 16)

fimAlocaMem:
    popq %r13                           # Restaura registradores
    popq %r12
    popq %rbx
    popq %rbp
    ret


# --------------------------------- liberaMem -----------------------------------
liberaMem:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx                          # %rbx guarda o cabeçalho do bloco
    pushq %r12                          # %r12 usado para cálculos temporários
    pushq %r13                          # %r13 guarda o bloco anterior (se existir)
    pushq %r14                          # %r14 usado como iterador

    # verifica se o ponteiro do bloco NULL
    cmpq $0, %rdi                       # Compara bloco com NULL
    jne notNULL                         # jmp se não for NULL
    movl $1, %eax                       # Se for NULL, retorna 1 (erro)
    jmp fimLiberaMem                    # Pula para o fim da função 

notNULL:
    # Calcula o endereço do cabeçalho do bloco (bloco - sizeof(Bloco))
    movq %rdi, %rbx                     # %rbx = bloco (argumento)
    subq $16, %rbx                      # Subtrai 16 bytes (tamanho da struct Bloco)

    # Marca o bloco como livre (ocupado = 0)
    movl $0, (%rbx)                     # Armazena 0 no campo 'ocupado' do cabeçalho

    # --- Fase 1: Fusão com o próximo bloco (se livre) ---
    movq %rbx, %r12                     # %r12 = cabeçalho do bloco atual
    movq 8(%r12), %rax                  # %rax = tamanho do bloco atual
    leaq 16(%r12, %rax), %r13           # %r13 = próximo bloco (atual + sizeof(Bloco) + tamanho)

    # Verifica se o próximo bloco está dentro dos limites da heap
    cmpq topoHeap(%rip), %r13           # Compara com o topo da heap
    jge noProxBloco                     # Se >= topo, não há próximo bloco
 
    # Verifica se o próximo bloco está livre
    cmpl $0, (%r13)                     # Verifica o campo 'ocupado' do próximo bloco
    jne noProxBloco                     # Se ocupado, não faz coalescência
    
    # Mescla com o próximo bloco (livre)
    movq 8(%r13), %rax                  # %rax = tamanho do próximo bloco
    addq $16, %rax                      # Adiciona sizeof(Bloco) ao tamanho
    addq %rax, 8(%r12)                  # Aumenta o tamanho do bloco atual

noProxBloco:
    # --- Fase 2: Fusão com o bloco anterior (se livre) ---
    movq inicioHeap(%rip), %r14         # %r14 = início da heap (primeiro bloco)
    movq $0, %r13                       # %r13 = NULL (ainda não encontrou anterior)

    # Loop para encontrar o bloco anterior ao atual
loopBlocoAnterior:
    cmpq %rbx, %r14                     # Compara iterador com bloco atual
    jge noAnterior                      # Se >=, não há anterior
    
    # Calcula o endereço do próximo bloco após o iterador
    movq 8(%r14), %rax                  # %rax = tamanho do bloco iterador
    leaq 16(%r14, %rax), %rax           # %rax = próximo bloco após iterador
    
    # Verifica se este próximo bloco é o bloco atual
    cmpq %rbx, %rax                     # Compara com bloco atual
    jne proxIt                          # Se diferente, continua procurando
    
    # Encontrou o bloco anterior
    movq %r14, %r13                     # %r13 = bloco anterior
    jmp verificaAntLivre                # Pula para verificar se está livre
    
proxIt:
    movq %rax, %r14                     # Avança iterador para o próximo bloco
    jmp loopBlocoAnterior               # Continua loop
    
verificaAntLivre:
    # Verifica se o bloco anterior existe e está livre
    cmpq $0, %r13                       # Verifica se anterior é NULL
    je noAnterior                       # Se não existe, não faz fusão
    cmpl $0, (%r13)                     # Verifica se anterior está livre
    jne noAnterior                      # Se ocupado, não faz fusão
    
    # Mescla com o bloco anterior (livre)
    movq 8(%rbx), %rax                  # %rax = tamanho do bloco atual
    addq $16, %rax                      # Adiciona sizeof(Bloco)
    addq %rax, 8(%r13)                  # Aumenta tamanho do bloco anterior
    movq %r13, %rbx                     # Atualiza bloco atual para o anterior (já mesclado)
    
noAnterior:
    # --- Fase 3: Verifica se todos os blocos estão livres ---
    movq inicioHeap(%rip), %r12         # %r12 = iterador (começa no início da heap)
    movl $1, %eax                       # %eax = 1 (assume que todos estão livres)
    
    # Loop para verificar todos os blocos
verificaTodosBlocos:
    cmpq topoHeap(%rip), %r12           # Verifica se iterador chegou ao topo
    jge todosBlocosLivres               # Se sim, todos estão livres
    
    cmpl $0, (%r12)                     # Verifica se bloco está ocupado
    je verificaProxBloco                # Se livre, continua
    
    # Bloco ocupado encontrado
    movl $0, %eax                       # Marca que não estão todos livres
    jmp todosBlocosLivres               # Sai do loop
    
verificaProxBloco:
    # Avança para o próximo bloco
    movq 8(%r12), %rdx                  # %rdx = tamanho do bloco atual
    leaq 16(%r12, %rdx), %r12           # %r12 = próximo bloco
    jmp verificaTodosBlocos             # Continua loop
    
todosBlocosLivres :
    # Se todos os blocos estiverem livres, reseta a heap
    cmpl $1, %eax                       # Verifica flag todos_livres
    jne fimLiberaMem                    # Se não, mantém a heap como está
    movq $0, inicioHeap(%rip)           # Se sim, reseta inicioHeap para NULL
    
fimLiberaMem:
    # Epílogo da função (restaura registradores e retorna)
    movl $0, %eax                       # Retorna 0 (sucesso)
    popq %r14                           # Restaura registradores salvos
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret                                 # Retorna ao chamador


# --------------------------------- imprimeMapa -----------------------------------
imprimeMapa:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx                          # Salva %rbx (usaremos para bloco atual)
    pushq %r12                          # Salva %r12 (contador)
    pushq %r13                          # Salva %r13 (tamanho do bloco)
    pushq %r14                          # Salva %r14 (símbolo)

    # Verifica se a heap está vazia
    cmpq $0, inicioHeap(%rip)
    jne mapa_nao_vazio
    
    # Heap vazia - imprime "<vazio>\n"
    movq $vazio_str, %rdi
    call printf
    jmp fim_imprime_mapa

mapa_nao_vazio:
    movq inicioHeap(%rip), %rbx         # %rbx = bloco atual

loop_blocos:
    # Verifica se chegou ao topo da heap
    cmpq topoHeap(%rip), %rbx
    jge fim_loop_blocos

    # Imprime a parte gerencial do bloco (16 bytes de '#')
    movq $16, %r12                      # %r12 = contador (16 bytes)
loop_gerencial:
    cmpq $0, %r12
    jle fim_loop_gerencial
    
    movq $format_str, %rdi              # Formato para printf
    movzbl char_hash(%rip), %esi        # Caractere '#'
    call printf
    
    decq %r12
    jmp loop_gerencial

fim_loop_gerencial:
    # Determina o símbolo a ser impresso (+ ou -)
    cmpl $0, (%rbx)                    # Verifica se bloco está ocupado
    je bloco_livre
    
    movzbl char_plus(%rip), %r14d       # Símbolo '+'
    jmp imprime_dados
    
bloco_livre:
    movzbl char_minus(%rip), %r14d      # Símbolo '-'

imprime_dados:
    # Imprime os dados do bloco (tamanho bytes do símbolo)
    movq 8(%rbx), %r13                  # %r13 = tamanho do bloco
    movq %r13, %r12                     # %r12 = contador

loop_dados:
    cmpq $0, %r12
    jle fim_loop_dados
    
    movq $format_str, %rdi              # Formato para printf
    movl %r14d, %esi                    # Caractere '+' ou '-'
    call printf
    
    decq %r12
    jmp loop_dados

fim_loop_dados:
    # Avança para o próximo bloco
    movq 8(%rbx), %rax                  # %rax = tamanho do bloco atual
    leaq 16(%rbx, %rax), %rbx           # %rbx = próximo bloco (atual + 16 + tamanho)
    jmp loop_blocos

fim_loop_blocos:
    # Imprime nova linha no final
    movq $newline_str, %rdi
    call printf

fim_imprime_mapa:
    popq %r14                           # Restaura registradores
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret