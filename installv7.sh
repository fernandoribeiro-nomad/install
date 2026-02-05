#!/bin/bash

# --- CONFIGURAÇÕES ---
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m'
TOTAL_APPS=11
SUCESSO=0

# INSIRA SEU TOKEN NOVO AQUI DENTRO TAMBÉM
TOKEN="SEU_NOVO_TOKEN_AQUI"
URL_ANYDESK="https://raw.githubusercontent.com/fernandoribeiro-nomad/installapps/main/AnyDesk_Custom_Client.deb"

# Garante que o script rode como root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Erro: Rode como sudo.${NC}"
  exit 1
fi

ACTIVE_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n 1)
UBUNTU_CODENAME=$(lsb_release -cs)

echo "Iniciando Automação..."

# 1. ESSENCIAIS
echo -n "1. Ferramentas essenciais: "
apt-get update > /dev/null 2>&1
apt-get install -y curl wget apt-transport-https gnupg2 lsb-release > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 2. PERMISSÕES
echo -n "2. Permissões de grupo: "
usermod -a -G netdev,lp,lpadmin,scanner,audio,video,bluetooth $ACTIVE_USER > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 3. FIREFOX
echo -n "3. Removendo Firefox: "
snap remove firefox > /dev/null 2>&1
apt-get purge -y firefox* > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 4. CHROME
echo -n "4. Google Chrome: "
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
apt-get install -y /tmp/chrome.deb > /dev/null 2>&1
rm /tmp/chrome.deb
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 5. ANYDESK (VIA GITHUB PRIVADO)
echo -n "5. AnyDesk Custom: "
curl -H "Authorization: Bearer $TOKEN" -L "$URL_ANYDESK" -o /tmp/anydesk.deb > /dev/null 2>&1
if [ -f "/tmp/anydesk.deb" ]; then
    apt-get install -y /tmp/anydesk.deb > /dev/null 2>&1
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
    rm /tmp/anydesk.deb
else
    echo -e "${VERMELHO}fail (download)${NC}"
fi

# 6. JUMPCLOUD
echo -n "6. JumpCloud: "
curl --tlsv1.2 --silent --show-error --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiJjYTU0ZmMwMzdkNzk4ZmIyZTExMDNjN2NiOGE0ODZhYzQ5NDFiYjY0In0g' https://kickstart.jumpcloud.com/Kickstart | bash > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 7. SLACK
echo -n "7. Slack: "
snap install slack --classic > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 8. CROWDSTRIKE
echo -n "8. CrowdStrike: "
export FALCON_CLIENT_ID="89c3c3b706a942ac95fa77b6ff1d8104"
export FALCON_CLIENT_SECRET="Ubx5E3CfFNIL0T1Oksehjl279BZMXp8u6WSPHm4y"
curl -L https://raw.githubusercontent.com/crowdstrike/falcon-scripts/main/bash/install/falcon-linux-install.sh 2>/dev/null | bash > /dev/null 2>&1
systemctl start falcon-sensor > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 9. NETSKOPE
echo -n "9. Netskope: "
wget -q https://nmd-nsclient.s3.amazonaws.com/NSClient.run -O /tmp/NSClient.run
chmod +x /tmp/NSClient.run
sh /tmp/NSClient.run -i -t nomadtecnologia-br -d eu.goskope.com > /dev/null 2>&1
IDUSER=$(id -u $ACTIVE_USER)
su -c "XDG_RUNTIME_DIR="/run/user/$IDUSER" DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus" systemctl --user --now enable stagentapp.service" $ACTIVE_USER > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 10. OPEN VPN 3
echo -n "10. OpenVPN 3: "
mkdir -p /etc/apt/keyrings
curl -sSfL https://swupdate.openvpn.net/repos/openvpn-repo-pkg-key.pub | gpg --dearmor --yes -o /etc/apt/keyrings/openvpn.gpg > /dev/null 2>&1
echo "deb [signed-by=/etc/apt/keyrings/openvpn.gpg] https://swupdate.openvpn.net/community/openvpn3/repos $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/openvpn3.list
apt-get update > /dev/null 2>&1
apt-get install -y openvpn3 > /dev/null 2>&1
echo -e "${VERDE}done${NC}"
((SUCESSO++))

# 11. GDM3
echo -n "11. GDM3 (Wayland/Login): "
GDM_CONFIG="/etc/gdm3/custom.conf"
sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' "$GDM_CONFIG"
sed -i 's/AutomaticLoginEnable=false/AutomaticLoginEnable=true/g' "$GDM_CONFIG"
sed -i "s/^#\?\(AutomaticLogin[[:space:]]*=[[:space:]]*\).*/\1$ACTIVE_USER/" "$GDM_CONFIG"
echo -e "${VERDE}done${NC}"
((SUCESSO++))

echo "--------------------------------------------------"
echo -e "Status: $SUCESSO de $TOTAL_APPS concluídos."
