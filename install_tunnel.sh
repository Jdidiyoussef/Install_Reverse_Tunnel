#!/bin/bash
set -e

echo "Install Reverse Tunnel"

read -p "VPS or Pi: " MODE
if [ "$MODE" == "VPS" ]; then
    
    	read -p "Port du tunnel (ex: 5000) : " REMOTE_PORT
	read -p "Utilisateur local (ex: pi) : " USER_PI

	SSHD_CONFIG="/etc/ssh/sshd_config"

	grep -n "AllowTcpForwarding" $SSHD_CONFIG || echo "❌ Add: AllowTcpForwarding yes"
	grep -n "GatewayPorts" $SSHD_CONFIG || echo "❌ Add: GatewayPorts yes"

	read -p "Did you fix SSH config? (yes/no): " CONFIRM
	[ "$CONFIRM" != "yes" ] && exit 1

	echo "sudo ufw allow $REMOTE_PORT"

	read -p "Did you configured the Pi ?(yes/no): " CONFIRM_Pi
	[ "$CONFIRM_Pi" != "yes" ] && exit 1

	if [ ! -f ~/.ssh/id_rsa ]; then
    		ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
	fi
	ssh-copy-id -p $REMOTE_PORT $USER_PI@localhost
	ssh -p $REMOTE_PORT $USER_PI@localhost
    
    exit 0
elif [ "$MODE" == "Pi" ]; then

	echo "Configuration PI"
	
	read -p "Enter new Server IP : " SERVER_IP
	echo "Using SERVER_IP = $SERVER_IP"

	read -p "Port du tunnel (ex: 5000) : " REMOTE_PORT
	echo "Port du tunnel = $REMOTE_PORT"

	read -p "Utilisateur local (ex: pi) : " USER_PI
	echo "Utilisateur local = $USER_PI"

	echo "=== Installation Autossh ==="
	sudo apt update
	sudo apt install -y autossh

	echo "=== Création du service systemd ==="

	sudo tee /etc/systemd/system/reverse-tunnel_test.service > /dev/null <<EOF
	[Unit]
	Description=Reverse SSH Tunnel to Contabo
	After=network-online.target
	Wants=network-online.target

	[Service]
	User=${USER_PI}
	Environment="AUTOSSH_GATETIME=0"
	ExecStartPre=/bin/sleep 10
	ExecStart=/usr/bin/autossh -N -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -R ${REMOTE_PORT}:localhost:22 root@${SERVER_IP}
	Restart=always
	RestartSec=5

	[Install]
	WantedBy=multi-user.target
	EOF

	echo "=== Génération de clé SSH ==="

	if [ ! -f ~/.ssh/id_rsa ]; then
	ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
	fi

	echo "=== Copie de la clé vers le serveur ==="
	ssh-copy-id root@${SERVER_IP}

	echo "=== Activation du service ==="
	sudo systemctl daemon-reload
	sudo systemctl enable reverse-tunnel_test.service
	sudo systemctl restart reverse-tunnel_test.service

	echo "=== Vérification ==="
	sudo systemctl status reverse-tunnel_test.service --no-pager

	read -p "Did you configured the VPS ?(yes/no): " CONFIRM_VPS
	[ "$CONFIRM_VPS" != "yes" ] && exit 1

	echo "Tunnel créé."

else 
	echo "Configuration not know"
fi


