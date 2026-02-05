#!/bin/bash

# --- CONFIGURAÇÕES DE CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m' # Sem cor

TOTAL_APPS=10
SUCESSO=0

# Garante que o script rode como root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Erro: Por favor, rode como root (sudo).${NC}"
  exit 1
fi

# Identifica o usuário real (quem deu sudo)
ACTIVE_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n 1)

echo "Iniciando processo de instalação e configuração..."
echo "Usuário detectado: $ACTIVE_USER"
echo "--------------------------------------------------"

# --- 1. FERRAMENTAS ESSENCIAIS ---
echo -n "1. Instalando ferramentas essenciais (CURL/WGET): "
rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock > /dev/null 2>&1
apt-get update > /dev/null 2>&1
apt-get install -y curl wget apt-transport-https gnupg2 > /dev/null 2>&1

if command -v curl >/dev/null 2>&1; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# --- 2. PERMISSÕES BÁSICAS DO USUÁRIO ---
echo -n "2. Configurando permissões de grupo: "
usermod -a -G netdev,lp,lpadmin,scanner,audio,video,bluetooth $ACTIVE_USER > /dev/null 2>&1
usermod -a -G pulse $ACTIVE_USER > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# --- 3. REMOÇÃO DO FIREFOX ---
echo -n "3. Removendo Firefox: "
apt-get purge -y firefox* > /dev/null 2>&1
snap remove firefox > /dev/null 2>&1
rm -rf /usr/lib/firefox /usr/lib/firefox-addons /etc/firefox > /dev/null 2>&1

if ! command -v firefox >/dev/null 2>&1; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# --- 4. INSTALAÇÃO DO GOOGLE CHROME ---
echo -n "4. Instalando Google Chrome: "
CHROME_DEB="/tmp/google-chrome-stable_current_amd64.deb"
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O "$CHROME_DEB" > /dev/null 2>&1

if [ -f "$CHROME_DEB" ]; then
    apt-get install -y "$CHROME_DEB" > /dev/null 2>&1
    rm -f "$CHROME_DEB"
fi

if command -v google-chrome-stable >/dev/null 2>&1; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# --- 5. ANYDESK (Instalação Local via .tar.gz) ---
echo -n "5. Instalando AnyDesk (Arquivo Local .tar.gz): "
# Caminho ajustado para .tar.gz
FILE_LOCAL="/home/$ACTIVE_USER/Documentos/AnyDesk_Custom_Client.tar.gz"
DEST_DIR="/opt/anydesk-custom"

# Instala dependências necessárias
apt-get install -y libpangocairo-1.0-0 libpango-1.0-0 libgtk-3-0 > /dev/null 2>&1

if [ -f "$FILE_LOCAL" ]; then
    mkdir -p $DEST_DIR
    # Extrai usando -z para arquivos .gz
    tar -xzf "$FILE_LOCAL" -C $DEST_DIR > /dev/null 2>&1
    
    # Procura o executável 'anydesk' dentro da pasta extraída (caso ele esteja em uma subpasta)
    EXE_PATH=$(find $DEST_DIR -name "anydesk" -type f | head -n 1)
    
    if [ -n "$EXE_PATH" ]; then
        chmod +x "$EXE_PATH"
        ln -sf "$EXE_PATH" /usr/bin/anydesk
        echo -e "${VERDE}done${NC}"
        ((SUCESSO++))
    else
        echo -e "${VERMELHO}fail (executável não encontrado no pacote)${NC}"
    fi
else
    echo -e "${VERMELHO}fail (arquivo não encontrado em Documentos)${NC}"
fi

# --- 6. JUMPCLOUD ---
echo -n "6. Instalando JumpCloud: "
curl --tlsv1.2 --silent --show-error --header 'x-connect-key: jcc_eyJwdWJsaWNLaWNrc3RhcnRVcmwiOiJodHRwczovL2tpY2tzdGFydC5qdW1wY2xvdWQuY29tIiwicHJpdmF0ZUtpY2tzdGFydFVybCI6Imh0dHBzOi8vcHJpdmF0ZS1raWNrc3RhcnQuanVtcGNsb3VkLmNvbSIsImNvbm5lY3RLZXkiOiJjYTU0ZmMwMzdkNzk4ZmIyZTExMDNjN2NiOGE0ODZhYzQ5NDFiYjY0In0g' https://kickstart.jumpcloud.com/Kickstart | bash > /dev/null 2>&1

if systemctl is-active --quiet jcagent; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# --- 7. SLACK ---
echo -n "7. Instalando Slack: "
snap install slack --classic > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# --- 8. CROWDSTRIKE FALCON ---
echo -n "8. Instalando CrowdStrike Falcon: "
export FALCON_CLIENT_ID="89c3c3b706a942ac95fa77b6ff1d8104"
export FALCON_CLIENT_SECRET="Ubx5E3CfFNIL0T1Oksehjl279BZMXp8u6WSPHm4y"

curl -L https://raw.githubusercontent.com/crowdstrike/falcon-scripts/main/bash/install/falcon-linux-install.sh 2>/dev/null | bash > /dev/null 2>&1

systemctl enable falcon-sensor > /dev/null 2>&1
systemctl start falcon-sensor > /dev/null 2>&1

if systemctl is-active --quiet falcon-sensor; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# --- 9. NETSKOPE ---
echo -n "9. Configurando Netskope: "
appTarget="netskope"

if pgrep -if $appTarget > /dev/null; then
    echo -e "${VERDE}done (já ativo)${NC}"
    ((SUCESSO++))
else
    apt-get install -y libgtk-3-0 libwebkit2gtk-4.0-37 libappindicator3-1 > /dev/null 2>&1
    wget -q https://nmd-nsclient.s3.amazonaws.com/NSClient.run -O /tmp/NSClient.run > /dev/null 2>&1
    chmod +x /tmp/NSClient.run
    sh /tmp/NSClient.run -i -t nomadtecnologia-br -d eu.goskope.com > /dev/null 2>&1
    
    IDUSER=$(id -u $ACTIVE_USER)
    su -c "XDG_RUNTIME_DIR="/run/user/$IDUSER" DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus" systemctl --user --now enable stagentapp.service" $ACTIVE_USER > /dev/null 2>&1
    
    sleep 5
    if pgrep -if "stAgentApp" > /dev/null; then
        echo -e "${VERDE}done${NC}"
        ((SUCESSO++))
    else
        echo -e "${VERMELHO}fail${NC}"
    fi
fi

# --- 10. OPEN VPN 3 ---
echo -n "10. Instalando OpenVPN 3: "
wget -q https://swupdate.openvpn.net/repos/openvpn-repo-pkg-key.pub -O /tmp/openvpn-key.pub > /dev/null 2>&1
apt-key add /tmp/openvpn-key.pub > /dev/null 2>&1
wget -q -O /etc/apt/sources.list.d/openvpn3.list https://swupdate.openvpn.net/community/openvpn3/repos/openvpn3-jammy.list > /dev/null 2>&1
apt-get update > /dev/null 2>&1
apt-get install -y openvpn3 > /dev/null 2>&1

if command -v openvpn3 >/dev/null 2>&1; then
    echo -e "${VERDE}done${NC}"
    ((SUCESSO++))
else
    echo -e "${VERMELHO}fail${NC}"
fi

# --- RELATÓRIO FINAL ---
PERCENTUAL=$(( (SUCESSO * 100) / TOTAL_APPS ))

echo "--------------------------------------------------"
echo "Grupos atuais do usuário $ACTIVE_USER:"
groups $ACTIVE_USER
echo "--------------------------------------------------"
echo -e "Resultado Final: ${PERCENTUAL}% de sucesso"
echo -e "Status: $SUCESSO de $TOTAL_APPS itens configurados."

if [ $SUCESSO -eq $TOTAL_APPS ]; then
    echo -e "${VERDE}Configuração completa com sucesso!${NC}"
else
    echo -e "${VERMELHO}Aviso: Algumas etapas falharam. Verifique manualmente.${NC}"
fi
