#!/bin/bash

# ==========================================================================
# Script de Automação de Instalação - Ubuntu 22.04
# ==========================================================================

# Cores para facilitar a leitura
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m' # Sem cor

# Contadores
TOTAL_SUCESSO=0
TOTAL_FALHA=0

# Função para verificar o status do último comando
# Uso: verificar_status "Nome da tarefa"
verificar_status() {
    if [ $? -eq 0 ]; then
        echo -e "${VERDE}[OK]${NC} - $1 concluído com sucesso."
        ((TOTAL_SUCESSO++))
    else
        echo -e "${VERMELHO}[FALHA]${NC} - $1 apresentou erro."
        ((TOTAL_FALHA++))
    fi
}

# 1. Validação de Privilégios (Script precisa de root)
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root (sudo)." 
   exit 1
fi

appTarget="netskope"

echo "----------------------------------------------------"
echo "Iniciando verificação do software: $appTarget"
echo "----------------------------------------------------"

# Valida se servico esta ativo
if pgrep -if $appTarget > /dev/null; then
    echo "Netskope já encontrado e ativo! Pulando instalação."
    ((TOTAL_SUCESSO++))
else
    # --- Início do Processo de Instalação ---

    # Atualiza lista de pacotes
    echo "Atualizando repositórios..."
    apt-get update -qq
    verificar_status "Atualização do apt-get"

    # Instala dependecias
    echo "Instalando dependências..."
    apt-get install -y libgtk-3-0 libwebkit2gtk-4.0-37 libappindicator3-1 wget > /dev/null 2>&1
    verificar_status "Instalação de dependências (libgtk, webkit, etc)"

    # Faz download do script
    echo "Baixando instalador..."
    wget -q https://nmd-nsclient.s3.amazonaws.com/NSClient.run -O /tmp/NSClient.run
    verificar_status "Download do NSClient.run"

    # Permissão de execução
    chmod +x /tmp/NSClient.run
    verificar_status "Permissão de execução no instalador"

    # Executa instalacao
    echo "Executando instalação do Netskope..."
    sh /tmp/NSClient.run -i -t nomadtecnologia-br -d eu.goskope.com > /dev/null 2>&1
    verificar_status "Execução do instalador (NSClient.run)"

    # Coleta usuário logado (considerando quem chamou o sudo ou o usuário da sessão X)
    CURRENT_USER=$(who | awk '{print $1}' | head -n1)
    IDUSER=$(id -u $CURRENT_USER)

    if [ -n "$CURRENT_USER" ]; then
        # Configuração do serviço no contexto do usuário
        echo "Habilitando serviço para o usuário: $CURRENT_USER (UID: $IDUSER)..."
        su -c "XDG_RUNTIME_DIR=/run/user/$IDUSER DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$IDUSER/bus systemctl --user --now enable stagentapp.service" $CURRENT_USER
        verificar_status "Habilitar serviço stagentapp via systemctl"
        
        sleep 5
        
        # Validação final do processo rodando
        if ps -ax | grep -v grep | grep "stAgentApp" > /dev/null; then
             echo -e "${VERDE}[OK]${NC} Processo stAgentApp detectado em execução."
             ((TOTAL_SUCESSO++))
        else
             echo -e "${VERMELHO}[FALHA]${NC} Processo stAgentApp não encontrado após instalação."
             ((TOTAL_FALHA++))
        fi
    else
        echo "Erro: Não foi possível identificar o usuário logado para habilitar o serviço."
        ((TOTAL_FALHA++))
    fi
fi

# ==========================================================================
# RESUMO FINAL
# ==========================================================================
echo "----------------------------------------------------"
echo "RELATÓRIO FINAL DA AUTOMAÇÃO"
echo "----------------------------------------------------"
echo -e "Tarefas com SUCESSO: ${VERDE}$TOTAL_SUCESSO${NC}"
echo -e "Tarefas com FALHA:   ${VERMELHO}$TOTAL_FALHA${NC}"
echo "----------------------------------------------------"

if [ $TOTAL_FALHA -eq 0 ]; then
    echo "Processo concluído integralmente sem erros."
    exit 0
else
    echo "Atenção: Houve erros durante o processo."
    exit 1
fi
