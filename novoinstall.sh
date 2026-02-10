#!/bin/bash

# --- CONFIGURAÇÕES DE CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
NC='\033[0m'

# VARIÁVEIS DE CONTROLE
TOTAL_APPS=15
SUCESSO=0
ACTIVE_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n 1)

# Garante que o script rode como root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Erro: Por favor, rode como root (sudo).${NC}"
  exit 1
fi

# --- FUNÇÕES DE INSTALAÇÃO ---

ferramentas_essenciais() {
    echo -e "${AMARELO}1. Instalando Ferramentas Essenciais...${NC}"
    apt-get update
    apt-get install -y curl wget apt-transport-https gnupg2 lsb-release
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

configurar_permissoes() {
    echo -e "${AMARELO}2. Configurando permissões de grupo...${NC}"
    usermod -a -G netdev,lp,lpadmin,scanner,audio,video,bluetooth,pulse $ACTIVE_USER
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

remover_firefox() {
    echo -e "${AMARELO}3. Removendo Firefox (Limpeza Total)...${NC}"
    pkill -9 firefox 2>/dev/null
    sudo snap remove --purge firefox
    sudo apt purge -y firefox firefox-locale-* firefox-esr
    sudo dpkg --list | grep -i "^rc.*firefox" | awk '{print $2}' | xargs -r sudo dpkg --purge
    sudo rm -f /usr/share/applications/firefox.desktop /usr/share/applications/firefox-esr.desktop
    rm -rf ~/.mozilla/firefox/ ~/snap/firefox/
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

desabilitar_ipv6() {
    echo -e "${AMARELO}4. Desabilitando IPv6...${NC}"
    sed -i '$a net.ipv6.conf.all.disable_ipv6 = 1' /etc/sysctl.conf
    sed -i '$a net.ipv6.conf.default.disable_ipv6 = 1' /etc/sysctl.conf
    sed -i '$a net.ipv6.conf.lo.disable_ipv6 = 1' /etc/sysctl.conf
    sed -i '$a net.ipv6.conf.eth0.disable_ipv6 = 1' /etc/sysctl.conf
    sysctl -p > /dev/null
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

instalar_chrome() {
    echo -e "${AMARELO}5. Instalando Google Chrome...${NC}"
    sudo apt-get update
    sudo apt-get install -y libxss1 libappindicator1 libindicator7
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    sudo apt install -y /tmp/chrome.deb
    rm /tmp/chrome.deb
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

instalar_anydesk() {
    echo -e "${AMARELO}6. Instalando AnyDesk Custom...${NC}"
    URL="https://raw.githubusercontent.com/fernandoribeiro-nomad/install/main/AnyDesk_Custom_Client.deb"
    wget -q "$URL" -O /tmp/anydesk.deb
    apt-get install -y /tmp/anydesk.deb
    rm /tmp/anydesk.deb
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

corrigir_conexao_anydesk() {
    echo -e "${AMARELO}7. Corrigindo Conexão AnyDesk (Wayland/Login)...${NC}"
    GDM_CONFIG="/etc/gdm3/custom.conf"
    sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' "$GDM_CONFIG"
    sed -i 's/AutomaticLoginEnable=false/AutomaticLoginEnable=true/g' "$GDM_CONFIG"
    sed -i "s/^#\?\(AutomaticLogin[[:space:]]*=[[:space:]]*\).*/\1$ACTIVE_USER/" "$GDM_CONFIG"
    ((SUCESSO++))
    echo -e "${VERDE}done (Requer reinicialização)${NC}"
}

instalar_jumpcloud() {
    echo -e "${AMARELO}8. Instalando JumpCloud...${NC}"
    curl --tlsv1.2 --silent --show-error --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiJjYTU0ZmMwMzdkNzk4ZmIyZTExMDNjN2NiOGE0ODZhYzQ5NDFiYjY0In0g' https://kickstart.jumpcloud.com/Kickstart | bash
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

instalar_slack() {
    echo -e "${AMARELO}9. Instalando Slack...${NC}"
    snap install slack --classic
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

instalar_crowdstrike() {
    echo -e "${AMARELO}10. Instalando CrowdStrike...${NC}"
    export FALCON_CLIENT_ID="89c3c3b706a942ac95fa77b6ff1d8104"
    export FALCON_CLIENT_SECRET="Ubx5E3CfFNIL0T1Oksehjl279BZMXp8u6WSPHm4y"
    curl -L https://raw.githubusercontent.com/crowdstrike/falcon-scripts/main/bash/install/falcon-linux-install.sh | bash
    systemctl start falcon-sensor
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

validar_crowdstrike() {
    echo -e "${AMARELO}11. Validando Status CrowdStrike...${NC}"
    systemctl status falcon-sensor --no-pager
    ((SUCESSO++))
}

instalar_netskope() {
    echo -e "${AMARELO}12. Instalando Netskope...${NC}"
    if pgrep -if "netskope" > /dev/null; then
        echo "Netskope já está ativo."
    else
        apt-get update
        apt-get install -y libgtk-3-0 libwebkit2gtk-4.0-37 libappindicator3-1 wget
        wget -q https://nmd-nsclient.s3.amazonaws.com/NSClient.run -O /tmp/NSClient.run
        chmod +x /tmp/NSClient.run
        sh /tmp/NSClient.run -i -t nomadtecnologia-br -d eu.goskope.com
        IDUSER=$(id -u $ACTIVE_USER)
        su -c "XDG_RUNTIME_DIR="/run/user/$IDUSER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$IDUSER/bus" systemctl --user --now enable stagentapp.service" $ACTIVE_USER
    fi
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

instalar_openvpn() {
    echo -e "${AMARELO}13. Instalando OpenVPN 3...${NC}"
    UBUNTU_CODENAME=$(lsb_release -cs)
    mkdir -p /etc/apt/keyrings
    curl -sSfL https://swupdate.openvpn.net/repos/openvpn-repo-pkg-key.pub | gpg --dearmor --yes -o /etc/apt/keyrings/openvpn.gpg
    echo "deb [signed-by=/etc/apt/keyrings/openvpn.gpg] https://swupdate.openvpn.net/community/openvpn3/repos $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/openvpn3.list
    apt-get update && apt-get install -y openvpn3
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

instalar_wazuh() {
    echo -e "${AMARELO}14. Instalando Wazuh Agent...${NC}"
    WAZUH_URL="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.12.0-1_amd64.deb"
    wget -q "$WAZUH_URL" -O /tmp/wazuh.deb
    WAZUH_MANAGER="wazuh-agents.nomadinternal.com" WAZUH_AGENT_GROUP="LNX_EndUsers" dpkg -i /tmp/wazuh.deb
    systemctl enable wazuh-agent && systemctl restart wazuh-agent
    ((SUCESSO++))
    echo -e "${VERDE}done${NC}"
}

validar_wazuh() {
    echo -e "${AMARELO}15. Validando Status Wazuh Agent...${NC}"
    sudo systemctl status wazuh-agent --no-pager
    ((SUCESSO++))
}

# --- MENU PRINCIPAL ---

exibir_menu() {
    clear
    echo "==========================================="
    echo "       AUTOMAÇÃO DE INSTALAÇÃO NOMAD       "
    echo "==========================================="
    echo "1) Ferramentas Essenciais"
    echo "2) Configurar Permissões de Grupo"
    echo "3) Remover Firefox (Limpeza Total)"
    echo "4) Desabilitar IPv6"
    echo "5) Instalar Google Chrome"
    echo "6) Instalar AnyDesk Custom"
    echo "7) Correção Conexão AnyDesk (Wayland/Login)"
    echo "8) Instalar JumpCloud"
    echo "9) Instalar Slack"
    echo "10) Instalar CrowdStrike"
    echo "11) VALIDAR Status CrowdStrike"
    echo "12) Instalar Netskope"
    echo "13) Instalar OpenVPN 3"
    echo "14) Instalar Wazuh Agent"
    echo "15) VALIDAR Status Wazuh Agent"
    echo "-------------------------------------------"
    echo "A) RODAR TUDO AUTOMATICAMENTE"
    echo "Q) Sair"
    echo "==========================================="
    echo -n "Escolha uma opção: "
}

while true; do
    exibir_menu
    read opcao
    case $opcao in
        1) ferramentas_essenciais ;;
        2) configurar_permissoes ;;
        3) remover_firefox ;;
        4) desabilitar_ipv6 ;;
        5) instalar_chrome ;;
        6) instalar_anydesk ;;
        7) corrigir_conexao_anydesk ;;
        8) instalar_jumpcloud ;;
        9) instalar_slack ;;
        10) instalar_crowdstrike ;;
        11) validar_crowdstrike ;;
        12) instalar_netskope ;;
        13) instalar_openvpn ;;
        14) instalar_wazuh ;;
        15) validar_wazuh ;;
        [Aa]) 
            ferramentas_essenciais
            configurar_permissoes
            remover_firefox
            desabilitar_ipv6
            instalar_chrome
            instalar_anydesk
            corrigir_conexao_anydesk
            instalar_jumpcloud
            instalar_slack
            instalar_crowdstrike
            validar_crowdstrike
            instalar_netskope
            instalar_openvpn
            instalar_wazuh
            validar_wazuh
            break
            ;;
        [Qq]) exit ;;
        *) echo "Opção inválida!" ; sleep 1 ;;
    esac
    echo -e "\nPressione Enter para continuar..."
    read
done

echo "--------------------------------------------------"
echo -e "${VERDE}FINALIZADO: $SUCESSO de $TOTAL_APPS etapas concluídas!${NC}"
echo "--------------------------------------------------"
