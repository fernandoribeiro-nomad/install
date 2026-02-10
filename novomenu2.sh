# ... (restante do script igual)

while true; do
    exibir_menu
    # A mágica está aqui: < /dev/tty faz ler do teclado e não do pipe
    read -r opcao < /dev/tty
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
        *) echo -e "${VERMELHO}Opção inválida!${NC}" ; sleep 2 ;;
    esac
    echo -e "\nPressione Enter para continuar..."
    read -r < /dev/tty
done
