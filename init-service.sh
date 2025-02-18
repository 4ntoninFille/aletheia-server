#!/bin/bash

SERVICE_NAME="aletheia-server"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
BINARY_PATH="/home/ubuntu/aletheia-server/aletheia-server"
CONF_SOURCE="./conf"
CONF_DEST="/etc/aletheia-server"
# should be the same in config.toml
LOGS_DIR="/var/log/aletheia-server"

# Create logs directory with correct permissions
sudo mkdir -p $LOGS_DIR
sudo chown ubuntu:ubuntu $LOGS_DIR
sudo chmod 755 $LOGS_DIR

create_service_file() {
    echo "Creating systemd service file for $SERVICE_NAME..."

    sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Aletheia Server
After=network.target

[Service]
ExecStart=$BINARY_PATH
WorkingDirectory=$CONF_DEST
Restart=always
RestartSec=10
User=ubuntu
Group=ubuntu
Environment=LOGS_DIR=$LOGS_DIR

[Install]
WantedBy=multi-user.target
EOL
    sudo chmod 644 $SERVICE_FILE
    echo "Service file created at $SERVICE_FILE."
}

copy_conf_folder() {
    echo "Copying configuration folder to $CONF_DEST..."
    sudo mkdir -p $CONF_DEST
    sudo cp -r $CONF_SOURCE/* $CONF_DEST
    sudo chown -R ubuntu:ubuntu $CONF_DEST
    sudo chmod -R 755 $CONF_DEST
    echo "Configuration folder copied."
}

set_binary_permissions() {
    echo "Setting execute permissions for the binary..."
    sudo chmod +x $BINARY_PATH
    sudo chown ubuntu:ubuntu "$(dirname $BINARY_PATH)"
    sudo chmod 755 "$(dirname $BINARY_PATH)"
    echo "Permissions set for $BINARY_PATH."
}

enable_and_start_service() {
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    echo "Enabling $SERVICE_NAME to start on boot..."
    sudo systemctl enable $SERVICE_NAME

    echo "Starting $SERVICE_NAME..."
    sudo systemctl start $SERVICE_NAME

    echo "$SERVICE_NAME service started."
}

check_service_status() {
    echo "Checking status of $SERVICE_NAME..."
    sudo systemctl status $SERVICE_NAME
}

create_service_file
copy_conf_folder
set_binary_permissions
enable_and_start_service
check_service_status