#!/bin/bash

# --- Configuration ---
PROXY_PORT=1500
PROXY_USER="atom"
PROXY_PASS="atom123" # Change this to a secure password!
LOG_FILE="/var/log/socks.log"

# 1. Update and Install Dante
echo "Installing Dante Server..."
apt update && apt install dante-server -y

# 2. Identify the active Network Interface
# This picks the interface with the default gateway
NIC=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
echo "Detected Network Interface: $NIC"

# 3. Create a clean Configuration
echo "Configuring Dante..."
cat <<EOF > /etc/danted.conf
logoutput: $LOG_FILE
internal: 0.0.0.0 port = $PROXY_PORT
external: $NIC

socksmethod: username
user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
EOF

# 4. Handle Log File Permissions
touch $LOG_FILE
chown nobody:nogroup $LOG_FILE

# 5. Create the Proxy User
# Check if user exists, if not, create it with password
if id "$PROXY_USER" &>/dev/null; then
    echo "User $PROXY_USER already exists. Updating password..."
    echo "$PROXY_USER:$PROXY_PASS" | chpasswd
else
    useradd -m -s /usr/sbin/nologin $PROXY_USER
    echo "$PROXY_USER:$PROXY_PASS" | chpasswd
    echo "User $PROXY_USER created."
fi

# 6. Open Firewall (UFW)
if command -v ufw &> /dev/null; then
    echo "Opening port $PROXY_PORT on UFW..."
    ufw allow $PROXY_PORT/tcp
fi

# 7. Restart and Enable
systemctl restart danted
systemctl enable danted

echo "------------------------------------------------"
echo "Setup Complete!"
echo "IP: $(curl -s https://ifconfig.me)"
echo "Port: $PROXY_PORT"
echo "User: $PROXY_USER"
echo "Pass: $PROXY_PASS"
echo "------------------------------------------------"
