#!/bin/bash

# --- CONFIGURAÇÕES DE CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
NC='\033[0m'

# VARIÁVEIS DE CONTROLE
TOTAL_APPS=13
SUCESSO=0
ACTIVE_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n 1)

# Garante que o script rode como root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Erro: Por favor, rode como root (sudo).${NC}"
  exit 1
fi

# --- FUNÇÕES (LOGICA DOS SEUS SCRIPTS) ---

instalar_chrome() {
    echo -e "${AMARELO}Instalando Google Chrome...${NC}"
    sudo apt-get update
    sudo apt-get install -y libxss1 libappindicator1 libindicator7
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    sudo apt install -y /tmp/chrome.deb
    if [ $? -eq 0 ]; then ((SUCESSO++)); echo -e "${VERDE}Chrome instalado!${NC}"; fi
}

remover_firefox() {
    echo -e "${AMARELO}Removendo Firefox (Limpeza Total)...${NC}"
    pkill -9 firefox 2>/dev/null
    sudo snap remove --purge firefox
    sudo apt purge -y firefox firefox-locale-* firefox-esr
    sudo dpkg --list | grep -i "^rc.*firefox" | awk '{print $2}' | xargs -r sudo dpkg --purge
    sudo rm -f /usr/share/applications/firefox.desktop /usr/share/applications/firefox-esr.desktop
    rm -rf ~/.mozilla/firefox/ ~/snap/firefox/
    echo -e "${VERDE}Firefox removido!${NC}"
    ((SUCESSO++))
}

desabilitar_ipv6() {
    echo -e "${AMARELO}Desabilitando IPv6...${NC}"
    sed -i '$a net.ipv6.conf.all.disable_ipv6 = 1' /etc/sysctl.conf
    sed -i '$a net.ipv6.conf.default.disable_ipv6 = 1' /etc/sysctl.conf
    sed -i '$a net.ipv6.conf.lo.disable_ipv6 = 1' /etc/sysctl.conf
    sed -i '$a net.ipv6.conf.eth0.disable_ipv6 = 1' /etc/sysctl.conf
    sysctl -p > /dev/null
    echo -e "${VERDE}IPv6 Desabilitado!${NC}"
    ((SUCESSO++))
}

instalar_netskope() {
    echo -e "${AMARELO}Instalando Netskope...${NC}"
    if pgrep -if "netskope" > /dev/null; then
        echo "Netskope encontrado e ativo!"
    else
        apt-get update
        apt-get install -y libgtk-3-0 libwebkit2gtk-4.0-37 libappindicator3-1 wget
        wget https://nmd-nsclient.s3.amazonaws.com/NSClient.run -O /tmp/NSClient.run
        chmod +x /tmp/NSClient.run
        sh /tmp/NSClient.run -i -t nomadtecnologia-br -d eu.goskope.com
        USER_NET=$(users | awk '{print $1}')
        IDUSER=`id $USER_NET | awk -F'[=($]' '{print $2}'`
        su -c "XDG_RUNTIME_DIR="/run/user/$IDUSER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$IDUSER/bus" systemctl --user --now enable stagentapp.service" $USER_NET
    fi
    ((SUCESSO++))
    echo -e "${VERDE}Netskope configurado!${NC}"
}

instalar_crowdstrike() {
    echo -e "${AMARELO}Instalando CrowdStrike...${NC}"
    export FALCON_CLIENT_ID="89c3c3b706a942ac95fa77b6ff1d8104"
    export FALCON_CLIENT_SECRET="Ubx5E3CfFNIL0T1Oksehjl279BZMXp8u6WSPHm4y"
    curl -L https://raw.githubusercontent.com/crowdstrike/falcon-scripts/main/bash/install/falcon-linux-install.sh | bash
    systemctl start falcon-sensor
    ((SUCESSO++))
    echo -e "${VERDE}CrowdStrike pronto!${NC}"
}

instalar_anydesk() {
    echo -e "${AMARELO}Instalando AnyDesk Custom...${NC}"
    URL="https://raw.githubusercontent.com/fernandoribeiro-nomad/install/main/AnyDesk_Custom_Client.deb"
    wget -q "$URL" -O /tmp/anydesk.deb
    apt-get install -y /tmp/anydesk.deb
    rm /tmp/anydesk.deb
    ((SUCESSO++))
    echo -e "${VERDE}AnyDesk pronto!${NC}"
}

instalar_jumpcloud() {
    echo -e "${AMARELO}Instalando JumpCloud...${NC}"
    curl --tlsv1.2 --silent --show-error --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiJjYTU0ZmMwMzdkNzk4ZmIyZTExMDNjN2NiOGE0ODZhYzQ5NDFiYjY0In0g' https://kickstart.jumpcloud.com/Kickstart | bash
    ((SUCESSO++))
    echo -e "${VERDE}JumpCloud pronto!${NC}"
}

instalar_slack() {
    echo -e "${AMARELO}Instalando Slack...${NC}"
    snap install slack --classic
    ((SUCESSO++))
    echo -e "${VERDE}Slack pronto!${NC}"
}

instalar_openvpn() {
    echo -e "${AMARELO}Instalando OpenVPN 3...${NC}"
    UBUNTU_CODENAME=$(lsb_release -cs)
    mkdir -p /etc/apt/keyrings
    curl -sSfL https://swupdate.openvpn.net/repos/openvpn-repo-pkg-key.pub | gpg --dearmor --yes -o /etc/apt/keyrings/openvpn.gpg
    echo "deb [signed-by=/etc/apt/keyrings/openvpn.gpg] https://swupdate.openvpn.net/community/openvpn3/repos $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/openvpn3.list
    apt-get update && apt-get install -y openvpn3
    ((SUCESSO++))
    echo -e "${VERDE}OpenVPN 3 pronto!${NC}"
}

configurar_gdm3() {
    echo -e "${AMARELO}Configurando Wayland e Login Automático...${NC}"
    GDM_CONFIG="/etc/gdm3/custom.conf"
    sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' "$GDM_CONFIG"
    sed -i 's/AutomaticLoginEnable=false/AutomaticLoginEnable=true/g' "$GDM_CONFIG"
    sed -i "s/^#\?\(AutomaticLogin[[:space:]]*=[[:space:]]*\).*/\1$ACTIVE_USER/" "$GDM_CONFIG"
    ((SUCESSO++))
    echo -e "${VERDE}GDM3 configurado!${NC}"
}

instalar_wazuh() {
    echo -e "${AMARELO}Instalando Wazuh Agent...${NC}"
    WAZUH_URL="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.12.0-1_amd64.deb"
    wget -q "$WAZUH_URL" -O /tmp/wazuh.deb
    WAZUH_MANAGER="wazuh-agents.nomadinternal.com" WAZUH_AGENT_GROUP="LNX_EndUsers" dpkg -i /tmp/wazuh.deb
    systemctl enable wazuh-agent && systemctl restart wazuh-agent
    ((SUCESSO++))
    echo -e "${VERDE}Wazuh pronto!${NC}"
}

configurar_permissoes() {
    echo -e "${AMARELO}Configurando permissões de grupo...${NC}"
    usermod -a -G netdev,lp,lpadmin,scanner,audio,video,bluetooth,pulse $ACTIVE_USER
    ((SUCESSO++))
    echo -e "${VERDE}Grupos configurados!${NC}"
}

ferramentas_essenciais() {
    echo -e "${AMARELO}Instalando Ferramentas Essenciais...${NC}"
    apt-get update
    apt-get install -y curl wget apt-transport-https gnupg2 lsb-release
    ((SUCESSO++))
    echo -e "${VERDE}Ferramentas prontas!${NC}"
}

# --- MENU PRINCIPAL ---

exibir_menu() {
    clear
    echo "==========================================="
    echo "       AUTOMAÇÃO DE INSTALAÇÃO NOMAD       "
    echo "==========================================="
    echo "1) Instalar Google Chrome"
    echo "2) Remover Firefox (Limpeza Total)"
    echo "3) Desabilitar IPv6"
    echo "4) Instalar Netskope"
    echo "5) Instalar CrowdStrike"
    echo "6) Instalar AnyDesk Custom"
    echo "7) Instalar JumpCloud"
    echo "8) Instalar Slack"
    echo "9) Instalar OpenVPN 3"
    echo "10) Corrigir GDM3 (Wayland/Login)"
    echo "11) Instalar Wazuh Agent"
    echo "12) Configurar Permissões de Grupo"
    echo "13) Instalar Ferramentas Essenciais"
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
        1) instalar_chrome ;;
        2) remover_firefox ;;
        3) desabilitar_ipv6 ;;
        4) instalar_netskope ;;
        5) instalar_crowdstrike ;;
        6) instalar_anydesk ;;
        7) instalar_jumpcloud ;;
        8) instalar_slack ;;
        9) instalar_openvpn ;;
        10) configurar_gdm3 ;;
        11) instalar_wazuh ;;
        12) configurar_permissoes ;;
        13) ferramentas_essenciais ;;
        [Aa]) 
            ferramentas_essenciais
            configurar_permissoes
            remover_firefox
            desabilitar_ipv6
            instalar_chrome
            instalar_anydesk
            instalar_jumpcloud
            instalar_slack
            instalar_crowdstrike
            instalar_netskope
            instalar_openvpn
            configurar_gdm3
            instalar_wazuh
            break
            ;;
        [Qq]) exit ;;
        *) echo "Opção inválida!" ; sleep 2 ;;
    esac
    echo -e "\nPressione Enter para continuar..."
    read
done

echo "--------------------------------------------------"
echo -e "${VERDE}FINALIZADO: $SUCESSO de $TOTAL_APPS concluídos com sucesso!${NC}"
echo "--------------------------------------------------"
