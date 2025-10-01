#!/bin/bash

BRANCH="$1"
DOMAIN="$2"
PROD_DOMAIN="prod.zepuff-test-task.pp.ua"
DEV_DOMAIN="dev.zepuff-test-task.pp.ua"

if [[ -z "$BRANCH" || -z "$DOMAIN" ]]; then
    echo "Usage: $0 <branch> <domain>"
    echo "Example: $0 dev dev.zepuff-test-task.pp.ua"
    exit 1
fi

echo "--- Starting Deployment for $BRANCH branch to $DOMAIN ---"

ansible-playbook ansible/playbook.yml -i inventory.ini --extra-vars "dev_domain=$DEV_DOMAIN prod_domain=$PROD_DOMAIN"

if [ $? -ne 0 ]; then
    echo "❌ ERROR: Ansible playbook failed. Deployment aborted."
    exit 1
fi

echo "--- Post-Deployment Checks Started ---"

echo "Checking HTTPS accessibility on https://$DOMAIN..."
if curl -sL --max-time 10 "https://$DOMAIN" > /dev/null; then
    echo "✅ HTTPS is accessible for $DOMAIN."
else
    echo "❌ ERROR: HTTPS is not accessible on $DOMAIN (Port 443 check failed)."
    exit 1
fi

echo "Checking SSL certificate validity..."

EXPIRY_DATE=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d'=' -f2)

if [[ -n "$EXPIRY_DATE" ]]; then
    EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    
    echo "Certificate is valid until: $EXPIRY_DATE"

    if [[ "$EXPIRY_TIMESTAMP" -gt "$CURRENT_TIMESTAMP" ]]; then
        EXPIRY_DAYS=$(( (EXPIRY_TIMESTAMP - CURRENT_TIMESTAMP) / 86400 ))
        echo "✅ Certificate is valid. Expires in $EXPIRY_DAYS days."
    else
        echo "❌ WARNING: Certificate has expired on $EXPIRY_DATE!"
        exit 1
    fi
else
    echo "❌ ERROR: Could not retrieve certificate expiry date or connection failed (check DNS/Firewall)."
    exit 1
fi

echo "--- Deployment and Checks Complete ---"
