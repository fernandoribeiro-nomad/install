#!/bin/bash

# --- CONFIGURAÇÕES DE CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m' # Sem cor

TOTAL_APPS=13
SUCESSO=0

# --- CONFIGURAÇÕES WAZUH ---
WAZUH_PACKAGE_URL="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.12.0-1_amd64.deb"
WAZUH_MANAGER_DOMAIN="wazuh-agents.nomadinternal.com"
WAZUH_MANAGER_IP="172.11.2.179"
WAZUH_AGENT_GROUP="LNX_EndUsers"

# --- CONFIGURAÇÕES GITHUB ---
URL_ANYDESK="https://raw.githubusercontent.com/fernandoribeiro-nomad/install/main/AnyDesk_Custom_Client.deb"

# Garante que o script rode como root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Erro: Por favor, rode como root (sudo).${NC}"
  exit 1
fi

ACTIVE_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n 1)
IDUSER_GLOBAL=$(id -u "$ACTIVE_USER")
UBUNTU_CODENAME=$(lsb_release -cs)

echo "Iniciando Automação Nomad..."
echo "Usuário: $ACTIVE_USER (UID: $IDUSER_GLOBAL) | Versão: $UBUNTU_CODENAME"
echo "--------------------------------------------------"

# 1. FERRAMENTAS ESSENCIAIS E DEPENDÊNCIAS DO NETSKOPE
echo -n "1. Ferramentas essenciais e dependências: "
apt-get update > /dev/null 2>&1
apt-get install -y \
    curl \
    wget \
    apt-transport-https \
    gnupg2 \
    lsb-release \
    libgtk-3-0 \
    libwebkit2gtk-4.0-37 \
    libappindicator3-1 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# 2. PERMISSÕES DE GRUPO
echo -n "2. Configurando permissões: "
usermod -a -G netdev,lp,lpadmin,scanner,audio,video,bluetooth $ACTIVE_USER > /dev/null 2>&1
usermod -a -G pulse $ACTIVE_USER > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 3. REMOÇÃO DO FIREFOX
echo -n "3. Removendo Firefox: "
snap remove firefox > /dev/null 2>&1
apt-get purge -y firefox* > /dev/null 2>&1
rm -rf /usr/lib/firefox /usr/lib/firefox-addons /etc/firefox > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 4. INSTALAÇÃO DO GOOGLE CHROME
echo -n "4. Instalando Google Chrome: "
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
apt-get install -y /tmp/chrome.deb > /dev/null 2>&1
rm /tmp/chrome.deb
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 5. DOWNLOAD ANYDESK CUSTOM
echo -n "5. Baixando AnyDesk Custom: "
wget -q "$URL_ANYDESK" -O /tmp/anydesk.deb
if [ -f "/tmp/anydesk.deb" ]; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# 6. INSTALAÇÃO ANYDESK CUSTOM
echo -n "6. Instalando AnyDesk Custom: "
if [ -f "/tmp/anydesk.deb" ]; then
    apt-get install -y /tmp/anydesk.deb > /dev/null 2>&1
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
    rm /tmp/anydesk.deb
else
    echo -e "${VERMELHO}fail${NC}"
fi

# 7. JUMPCLOUD
echo -n "7. Instalando JumpCloud: "
curl --tlsv1.2 --silent --show-error --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiJjYTU0ZmMwMzdkNzk4ZmIyZTExMDNjN2NiOGE0ODZhYzQ5NDFiYjY0In0g' https://kickstart.jumpcloud.com/Kickstart | bash > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 8. SLACK
echo -n "8. Instalando Slack: "
snap install slack --classic > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 9. CROWDSTRIKE FALCON
echo -n "9. Instalando CrowdStrike: "
export FALCON_CLIENT_ID="89c3c3b706a942ac95fa77b6ff1d8104"
export FALCON_CLIENT_SECRET="Ubx5E3CfFNIL0T1Oksehjl279BZMXp8u6WSPHm4y"
curl -L https://raw.githubusercontent.com/crowdstrike/falcon-scripts/main/bash/install/falcon-linux-install.sh 2>/dev/null | bash > /dev/null 2>&1
systemctl start falcon-sensor > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 10. NETSKOPE (Instalação integrada)
echo -n "10. Configurando Netskope: "
appTarget="netskope"
if pgrep -if $appTarget > /dev/null
then
	echo -e "${VERDE}já ativo${NC}"
	((SUCESSO++))
else
	# Faz download do script e armazena no tmp
	wget -q https://nmd-nsclient.s3.amazonaws.com/NSClient.run -O /tmp/NSClient.run
	# Adiciona permissao de execucao no script
	chmod +x /tmp/NSClient.run
	# Executa instalacao informando paramentros da organizacao
	sh /tmp/NSClient.run -i -t nomadtecnologia-br -d eu.goskope.com > /dev/null 2>&1
	# Coleta usuario logado
	USER=$(users | awk '{print $1}')
	# Coleta o uid do usario
	IDUSER=`id $USER | awk -F'[=($]' '{print $2}'`
	# Executa processo para habilitar agente
	su -c "XDG_RUNTIME_DIR="/run/user/$IDUSER" DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus" systemctl --user --now enable stagentapp.service" $USER > /dev/null 2>&1
	# Pausa
	sleep 5
	# Validação
	if pgrep -if "stAgentApp" > /dev/null; then
		echo -e "${VERDE}done${NC}"
		((SUCESSO++))
	else
		echo -e "${VERMELHO}fail${NC}"
	fi
fi

# 11. OPEN VPN 3
echo -n "11. Instalando OpenVPN 3: "
mkdir -p /etc/apt/keyrings
curl -sSfL https://swupdate.openvpn.net/repos/openvpn-repo-pkg-key.pub | gpg --dearmor --yes -o /etc/apt/keyrings/openvpn.gpg > /dev/null 2>&1
echo "deb [signed-by=/etc/apt/keyrings/openvpn.gpg] https://swupdate.openvpn.net/community/openvpn3/repos $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/openvpn3.list
apt-get update > /dev/null 2>&1
apt-get install -y openvpn3 > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 12. WAZUH AGENT (Instalação, Update e Sync)
echo -n "12. Instalando/Configurando Wazuh: "
WAZUH_PKG_NAME=$(basename "$WAZUH_PACKAGE_URL")
WAZUH_ERR=0

if ! dpkg -l | grep -q wazuh-agent; then
    wget -q "$WAZUH_PACKAGE_URL" -O /tmp/"$WAZUH_PKG_NAME"
    WAZUH_MANAGER="$WAZUH_MANAGER_DOMAIN" WAZUH_AGENT_GROUP="$WAZUH_AGENT_GROUP" dpkg -i /tmp/"$WAZUH_PKG_NAME" > /dev/null 2>&1 || WAZUH_ERR=1
    systemctl enable wazuh-agent > /dev/null 2>&1
    systemctl start wazuh-agent > /dev/null 2>&1
else
    INSTALLED_VER=$(dpkg -l wazuh-agent | grep wazuh-agent | awk '{print $3}')
    REPO_VER=$(echo "$WAZUH_PACKAGE_URL" | grep -oP 'wazuh-agent_\K[^_]+')
    if [ "$INSTALLED_VER" != "$REPO_VER" ]; then
        wget -q "$WAZUH_PACKAGE_URL" -O /tmp/"$WAZUH_PKG_NAME"
        WAZUH_MANAGER="$WAZUH_MANAGER_DOMAIN" WAZUH_AGENT_GROUP="$WAZUH_AGENT_GROUP" dpkg -i /tmp/"$WAZUH_PKG_NAME" > /dev/null 2>&1 || WAZUH_ERR=1
        systemctl restart wazuh-agent > /dev/null 2>&1
    fi
fi
rm -f /tmp/"$WAZUH_PKG_NAME"

if [ -f "/var/ossec/etc/ossec.conf" ]; then
    if grep -q "<address>$WAZUH_MANAGER_IP</address>" /var/ossec/etc/ossec.conf; then
        sed -i "s|<address>$WAZUH_MANAGER_IP</address>|<address>$WAZUH_MANAGER_DOMAIN</address>|g" /var/ossec/etc/ossec.conf
        systemctl restart wazuh-agent > /dev/null 2>&1
    fi
fi

if [ $WAZUH_ERR -eq 0 ]; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# 13. CORREÇÕES GDM3 (Wayland / Login)
echo -n "13. Corrigindo Wayland/Login: "
GDM_CONFIG="/etc/gdm3/custom.conf"
if [ -f "$GDM_CONFIG" ]; then
    sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' "$GDM_CONFIG"
    sed -i 's/AutomaticLoginEnable=false/AutomaticLoginEnable=true/g' "$GDM_CONFIG"
    sed -i "s/^#\?\(AutomaticLogin[[:space:]]*=[[:space:]]*\).*/\1$ACTIVE_USER/" "$GDM_CONFIG"
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

echo "--------------------------------------------------"
echo -e "Finalizado: $SUCESSO de $TOTAL_APPS concluídos."
