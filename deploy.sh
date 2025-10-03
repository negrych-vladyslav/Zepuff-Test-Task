#!/bin/bash

# ==========================================================
# SCRIPTS DEPLOY.SH - ЄДИНА ТОЧКА ВХОДУ ДЛЯ CI/CD
#
# Використання: bash deploy.sh <dev|main> <шлях_до_vault_pass.txt>
#
# ЯК БЕЗПЕЧНО ПЕРЕДАТИ ОБЛІКОВІ ДАНІ (ВАЖЛИВО):
# Встановіть змінну оточення перед запуском:
# export BASIC_AUTH_CREDENTIALS="admin:your_secret_password"
# ==========================================================

# 1. Налаштування змінних та перевірка аргументів
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Помилка: Необхідно вказати гілку та шлях до файлу з паролем Vault."
    echo "Використання: bash deploy.sh <dev|main> <шлях_до_vault_pass.txt>"
    exit 1
fi

BRANCH="$1"
VAULT_PASS_FILE="$2"
ANSIBLE_INVENTORY="ansible/inventory"
ANSIBLE_PLAYBOOK="ansible/playbook.yml"
PROD_DOMAIN="prod.zepuff-test-task.pp.ua"
DEV_DOMAIN="dev.zepuff-test-task.pp.ua"

# Визначаємо середовище для Ansible (main -> prod, dev -> dev)
if [ "$BRANCH" == "main" ]; then
    TARGET_ENV="prod"
else
    TARGET_ENV="dev"
fi

# 2. Формування заголовків та КРИТИЧНА перевірка Basic Auth для Prod
AUTH_HEADER=""
if [ "$TARGET_ENV" == "prod" ]; then
    if [ -z "$BASIC_AUTH_CREDENTIALS" ]; then
        echo "=========================================================="
        echo "❌ ПОМИЛКА: Для 'prod' необхідна змінна BASIC_AUTH_CREDENTIALS."
        echo "=========================================================="
        exit 1
    else
        AUTH_HEADER="-u $BASIC_AUTH_CREDENTIALS"
    fi
fi

# ==========================================================
# ФУНКЦІЯ ПЕРЕВІРКИ (HEALTH CHECK)
# ==========================================================

# Функція перевіряє: 
# 1. HTTPS доступність
# 2. Валідність сертифіката (якщо prod)
# 3. Успішний Basic Auth (якщо prod)
run_final_check() {
    local domain=$1
    local auth_data=$BASIC_AUTH_CREDENTIALS
    local target_env=$3
    
    # Прапори для curl
    local curl_flags="-s --fail -o /dev/null"
    
    if [ "$target_env" == "dev" ]; then
        # Дозволяємо невалідні сертифікати для Dev (-k)
        curl_flags="-s -k --fail -o /dev/null"
    fi

    echo "🌐 Запуск фінальної перевірки $domain (Використання: curl --fail)..."
    
    # Виконуємо команду, яка успішно працювала локально
    curl $curl_flags -u "$auth_data" "https://$domain"

    CURL_EXIT_CODE=$?

    if [ $CURL_EXIT_CODE -eq 0 ]; then
        echo "✅ $domain: Успіх (Код виходу 0). Усі перевірки (HTTPS, Сертифікат, Auth) пройдені."
        return 0
    else
        # Обробка типових помилок
        if [ "$target_env" == "prod" ] && [ "$CURL_EXIT_CODE" -eq 6 ]; then
             echo "❌ $domain: Помилка 6 (Could not resolve host). Проблема з DNS або мережею."
        elif [ "$target_env" == "prod" ] && [ "$CURL_EXIT_CODE" -eq 60 ]; then
             echo "❌ $domain: Помилка 60 (SSL Certificate Problem). Сертифікат НЕ дійсний."
        elif [ "$target_env" == "prod" ]; then
             echo "❌ $domain: Провал перевірки (Код $CURL_EXIT_CODE). Можлива помилка 401 (Basic Auth) або 5xx."
        else
             echo "❌ $domain: Провал перевірки (Код $CURL_EXIT_CODE)."
        fi
        return 1
    fi
}

# ==========================================================
# ОСНОВНА ЛОГІКА ДЕПЛОЮ
# ==========================================================

echo "=========================================================="
echo "🚀 Запуск деплою для гілки: $BRANCH (Середовище: $TARGET_ENV)"
echo "=========================================================="

# 3. Виконання Ansible Playbook
ansible-playbook -i "$ANSIBLE_INVENTORY" "$ANSIBLE_PLAYBOOK" \
    -e branch=$TARGET_ENV \
    --vault-password-file "$VAULT_PASS_FILE"

# 4. Перевірка статусу виконання Ansible
if [ $? -ne 0 ]; then
    echo "=========================================================="
    echo "❌ Деплой для гілки $BRANCH завершився з помилкою Ansible."
    echo "=========================================================="
    exit 1
fi

echo "=========================================================="
echo "✅ Ansible завершив роботу. Запуск Health Check..."
echo "=========================================================="

# 5. Виконання фінальної перевірки
if [ "$TARGET_ENV" == "prod" ]; then
    TARGET_DOMAIN="$PROD_DOMAIN"
else
    TARGET_DOMAIN="$DEV_DOMAIN"
fi

# Виконуємо лише одну перевірку
TOTAL_CHECKS=1
if run_final_check "$TARGET_DOMAIN" "$AUTH_HEADER" "$TARGET_ENV"; then
    echo "=========================================================="
    echo "🎉 Успіх! Деплой $BRANCH та всі перевірки пройдені."
    echo "=========================================================="
    exit 0
else
    echo "=========================================================="
    echo "🔥 Помилка! Health Check не пройшов. CI/CD буде зупинено."
    echo "=========================================================="
    exit 1
fi
