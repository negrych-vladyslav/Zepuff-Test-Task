#!/bin/bash

# ==========================================================
# КОНФІГУРАЦІЯ
# ==========================================================
DOMAINS=("prod.zepuff-test-task.pp.ua" "dev.zepuff-test-task.pp.ua")
EMAIL="example@gmail.com" 
DATA_PATH="./data/certbot"
RSA_KEY_SIZE=4096

# Назва для директорії сертифікатів (відповідає змінній в Ansible)
CERT_NAME="devops-project" 

# ==========================================================
# ПЕРЕВІРКА ТА ПОПЕРЕДНЄ НАЛАШТУВАННЯ
# ==========================================================
if [ -d "$DATA_PATH/conf/live/$CERT_NAME" ]; then
echo "### Існуючі сертифікати для $CERT_NAME знайдено. Пропускаємо ініціалізацію. ###"
exit 0
fi

echo "### Завантажуємо рекомендовані параметри TLS... ###"
mkdir -p "$DATA_PATH/conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$DATA_PATH/conf/options-ssl-nginx.conf"
curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$DATA_PATH/conf/ssl-dhparams.pem"
echo

echo "### Створюємо тимчасовий сертифікат для $CERT_NAME... ###"
PATH_TMP="/etc/letsencrypt/live/$CERT_NAME" # Використовуємо CERT_NAME
mkdir -p "$DATA_PATH/conf/live/$CERT_NAME"
docker compose run --rm --entrypoint "\
openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1\
-keyout '$PATH_TMP/privkey.pem' \
-out '$PATH_TMP/fullchain.pem' \
-subj '/CN=localhost'" certbot
echo

echo "### Запускаємо Nginx... ###"
# Припускаємо, що docker-compose-prod.yml містить Nginx
docker compose -f docker-compose-prod.yml up -d nginx-reverse-proxy

# ==========================================================
# ВИДАЛЕННЯ ТИМЧАСОВИХ ФАЙЛІВ
# ==========================================================
echo "### Видаляємо тимчасовий сертифікат... ###"
docker compose run --rm --entrypoint "\
rm -Rf /etc/letsencrypt/live/$CERT_NAME && \
rm -Rf /etc/letsencrypt/archive/$CERT_NAME && \
rm -Rf /etc/letsencrypt/renewal/$CERT_NAME.conf" certbot
echo

# ==========================================================
# ЗАПИТ СПРАВЖНЬОГО СЕРТИФІКАТА
# ==========================================================
echo "### Запитуємо справжній сертифікат Let's Encrypt для всіх доменів... ###"
DOMAIN_ARGS=""
for DOMAIN in "${DOMAINS[@]}"; do
DOMAIN_ARGS="$DOMAIN_ARGS -d $DOMAIN"
done

EMAIL_ARG="--email $EMAIL --agree-tos --no-eff-email"

docker compose run --rm --entrypoint "\
certbot certonly --webroot -w /var/www/certbot \
$EMAIL_ARG \
$DOMAIN_ARGS \
--rsa-key-size $RSA_KEY_SIZE \
--force-renewal \
--cert-name $CERT_NAME" certbot # ⬅️ Ось це забезпечує фіксовану назву директорії
echo

# ==========================================================
# ЗАВЕРШЕННЯ
# ==========================================================
echo "### Перезавантажуємо Nginx... ###"
docker compose exec nginx-reverse-proxy nginx -s reload

echo "### Готово! ###"