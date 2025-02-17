#!/bin/bash

SERVICE_NAME="aletheia-server"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
BINARY_PATH="/path/to/aletheia-server"  # Update this path to the actual location of the binary
CONF_SOURCE="./conf"
CONF_DEST="/etc/aletheia-server"

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
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOL

    echo "Service file created at $SERVICE_FILE."
}

copy_conf_folder() {
    echo "Copying configuration folder to $CONF_DEST..."
    sudo mkdir -p $CONF_DEST
    sudo cp -r $CONF_SOURCE/* $CONF_DEST
    echo "Configuration folder copied."
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
enable_and_start_service
check_service_status