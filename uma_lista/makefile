# Nome do executável final
EXEC = teste

# Arquivos-fonte
ASM = meuAlocador.s
C_SRC = exemplo.c

# Arquivos objeto
OBJ = exemplo.o meuAlocador.o

# Compiladores
AS = as
CC = gcc

# Flags
CFLAGS = -c
LDFLAGS = -no-pie

# Regras
all: $(EXEC)

alocador2.o: $(ASM)
	$(AS) $< -o $@

exemplo.o: $(C_SRC)
	$(CC) $(CFLAGS) $< -o $@

$(EXEC): $(OBJ)
	$(CC) $(LDFLAGS) $(OBJ) -o $(EXEC)

clean:
	rm -f $(OBJ) $(EXEC)
