#!/bin/bash

LOG_FILE="/var/log/ssh_security_checker.log"

check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root."
        echo "$(date) - ERROR - Script not run as root." >> "$LOG_FILE"
        exit 1
    fi
}

log_and_echo() {
    echo "$1"
    echo "$(date) - $1" >> "$LOG_FILE"
}

check_sshd_config() {
    CONFIG_FILE="/etc/ssh/sshd_config"
    if [ ! -f "$CONFIG_FILE" ]; then
        log_and_echo "SSHD config file not found!"
        exit 1
    fi

    log_and_echo "Checking SSHD security settings..."

    grep -q "^PermitRootLogin no" "$CONFIG_FILE" && log_and_echo "Root login is disabled." || log_and_echo "Root login is NOT disabled."
    grep -q "^PasswordAuthentication no" "$CONFIG_FILE" && log_and_echo "Password authentication is disabled." || log_and_echo "Password authentication is NOT disabled."
    grep -q "^Protocol 2" "$CONFIG_FILE" && log_and_echo "Using secure SSH protocol version 2." || log_and_echo "SSH protocol version is not set to 2."
    grep -q "^AllowUsers" "$CONFIG_FILE" && log_and_echo "Specific AllowUsers directive is set." || log_and_echo "No AllowUsers directive set — all users can connect."
    grep -q "^PermitEmptyPasswords no" "$CONFIG_FILE" && log_and_echo "Empty passwords are disabled." || log_and_echo "Empty passwords are NOT disabled."

    if grep -q "^PubkeyAuthentication yes" "$CONFIG_FILE"; then
        log_and_echo "SSH key authentication is enabled."
    else
        log_and_echo "SSH key authentication is NOT explicitly enabled. It's recommended to enable PubkeyAuthentication."
    fi
}

check_failed_logins() {
    log_and_echo "Checking for failed SSH login attempts in auth log..."

    if [ -f /var/log/auth.log ]; then
        FAILED=$(grep "Failed password" /var/log/auth.log | wc -l)
        log_and_echo "Failed SSH login attempts (auth.log): $FAILED"
    elif [ -f /var/log/secure ]; then
        FAILED=$(grep "Failed password" /var/log/secure | wc -l)
        log_and_echo "Failed SSH login attempts (secure): $FAILED"
    else
        log_and_echo "Unable to locate authentication log file (/var/log/auth.log or /var/log/secure)."
    fi
}

main() {
    check_permissions
    log_and_echo "Starting SSH Security Check..."
    check_sshd_config
    check_failed_logins
    log_and_echo "SSH Security Check complete."
}

main
