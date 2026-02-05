#!/bin/bash

# --- CONFIGURAÇÕES DE CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m' # Sem cor

TOTAL_APPS=12
SUCESSO=0

# URL do AnyDesk no seu repositório público
URL_ANYDESK="https://raw.githubusercontent.com/fernandoribeiro-nomad/install/main/AnyDesk_Custom_Client.deb"

# Garante que o script rode como root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Erro: Por favor, rode como root (sudo).${NC}"
  exit 1
fi

ACTIVE_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n 1)
UBUNTU_CODENAME=$(lsb_release -cs)

echo "Iniciando Automação Nomad..."
echo "--------------------------------------------------"

# 1. FERRAMENTAS ESSENCIAIS
echo -n "1. Ferramentas essenciais: "
apt-get update > /dev/null 2>&1
apt-get install -y curl wget apt-transport-https gnupg2 lsb-release > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

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

# 5. DOWNLOAD DOS ARQUIVOS LOCAIS (ANYDESK)
echo -n "5. Baixando instalador AnyDesk Custom: "
wget -q "$URL_ANYDESK" -O /tmp/anydesk.deb
if [ -f "/tmp/anydesk.deb" ]; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# 6. INSTALAÇÃO DO ANYDESK
echo -n "6. Instalando AnyDesk Custom: "
if [ -f "/tmp/anydesk.deb" ]; then
    apt-get install -y /tmp/anydesk.deb > /dev/null 2>&1
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
    rm /tmp/anydesk.deb
else
    echo -e "${VERMELHO}fail (arquivo não encontrado)${NC}"
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

# 10. NETSKOPE
echo -n "10. Configurando Netskope: "

# Passo 1: Dependências - Adicionado libwebkit2gtk-4.1-0 para compatibilidade com Ubuntu 22.04+
apt-get update -qq
apt-get install -y libgtk-3-0 libwebkit2gtk-4.0-37 libwebkit2gtk-4.1-0 libappindicator3-1 wget > /dev/null 2>&1

# Passo 2: Download e Instalação
wget -q https://nmd-nsclient.s3.amazonaws.com/NSClient.run -O /tmp/NSClient.run
chmod +x /tmp/NSClient.run
sh /tmp/NSClient.run -i -t nomadtecnologia-br -d eu.goskope.com > /dev/null 2>&1

# Passo 3: Preparar ambiente para o usuário
IDUSER=$(id -u $ACTIVE_USER)
XAUTH="/home/$ACTIVE_USER/.Xauthority"

# Passo 4: Habilitar e Iniciar garantindo acesso ao X11
# O uso de XAUTHORITY é o que geralmente resolve a tela não aparecer
sudo -u $ACTIVE_USER DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$IDUSER/bus" \
    XDG_RUNTIME_DIR="/run/user/$IDUSER" \
    DISPLAY=:0 \
    XAUTHORITY=$XAUTH \
    systemctl --user daemon-reload > /dev/null 2>&1

sudo -u $ACTIVE_USER DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$IDUSER/bus" \
    XDG_RUNTIME_DIR="/run/user/$IDUSER" \
    DISPLAY=:0 \
    XAUTHORITY=$XAUTH \
    systemctl --user enable stagentapp.service > /dev/null 2>&1

# Tenta abrir o App manualmente se o serviço não subir a tela
sudo -u $ACTIVE_USER DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$IDUSER/bus" \
    XDG_RUNTIME_DIR="/run/user/$IDUSER" \
    DISPLAY=:0 \
    XAUTHORITY=$XAUTH \
    /opt/netskope/stagent/stAgentApp > /dev/null 2>&1 &

echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 11. OPEN VPN 3
echo -n "11. Instalando OpenVPN 3: "
mkdir -p /etc/apt/keyrings
curl -sSfL https://swupdate.openvpn.net/repos/openvpn-repo-pkg-key.pub | gpg --dearmor --yes -o /etc/apt/keyrings/openvpn.gpg > /dev/null 2>&1
echo "deb [signed-by=/etc/apt/keyrings/openvpn.gpg] https://swupdate.openvpn.net/community/openvpn3/repos $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/openvpn3.list
apt-get update > /dev/null 2>&1
apt-get install -y openvpn3 > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 12. CORREÇÕES GDM3 (Wayland / Login)
echo -n "12. Corrigindo Wayland/Login: "
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
