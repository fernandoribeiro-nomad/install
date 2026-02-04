#!/bin/bash
# Nome do servico
appTarget="netskope"
# Valida se servico esta ativo
if pgrep -if $appTarget > /dev/null
then
	# Se existe, apenas registrar retorno positivo
	echo "Netskope encontrado e ativo!"
else
	# Se nao existir servico, inicia processo de instalacao e preparacao do agente
	# Atualiza lista de pacotes
	apt-get update
	# Instala dependecias
	apt-get install -y libgtk-3-0 libwebkit2gtk-4.0-37 libappindicator3-1 wget
	# Faz download do script e armazena no tmp
	wget https://nmd-nsclient.s3.amazonaws.com/NSClient.run -O /tmp/NSClient.run
        #wget https://nmd-nsclient.s3.amazonaws.com/STAgent.run -O /tmp/NSClient.run
	# Adiciona permissao de execucao no script
	chmod +x /tmp/NSClient.run
	# Executa instalacao informando paramentros da organizacao
	sh /tmp/NSClient.run -i -t nomadtecnologia-br -d eu.goskope.com
	# Coleta usuario logado
	USER=$(users)
	# Coleta o uid do usario
	IDUSER=`id $USER | awk -F'[=($]' '{print $2}'`
	# Executa processo para habilitar agente
	su -c "XDG_RUNTIME_DIR="/run/user/$IDUSER" DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus" systemctl --user --now enable stagentapp.service" $USER
	# Pausa
	sleep 5
	# Exibe processo do agente em execucao
	ps -ax -o user:96,pid,cmd | grep "[s]tAgentApp"
fi
exit
