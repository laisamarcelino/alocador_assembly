# Alocador de Memória em Assembly x86_64

![Assembly](https://img.shields.io/badge/Assembly-x86__64-red) 
![Licença](https://img.shields.io/badge/Licen%C3%A7a-MIT-green)

## 📝 Descrição
Implementação em linguagem Assembly x86_64 de um alocador dinâmico de memória, equivalente às funções `malloc` e `free` em C. O projeto inclui todas as operações básicas de gerenciamento de memória e visualização do estado do heap.

## ⚙️ Funcionalidades

- [x] Alocação de memória com estratégia first-fit
- [x] Liberação de memória com coalescência automática
- [x] Visualização gráfica do mapa de memória
- [x] Gerenciamento de listas de blocos livres e ocupados
- [x] Redefinição completa do alocador

## 🏗️ Estrutura do Projeto
- Uma lista: algoritmo implementado utilizando uma única lista
- Duas listas: algoritmo implementado utilizando duas listas, uma com os nós livres e outra com os nós ocupados.

### 🔠 Compilação e execução

```
make
./teste

```