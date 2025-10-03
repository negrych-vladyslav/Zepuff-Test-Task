#Zepuff-Test-Task
# 🚀 Node.js CI/CD на GCP з Ansible, Docker та Certbot

Цей проєкт реалізує надійний, автоматизований процес доставки (CI/CD) для Node.js застосунків, розгорнутих на віртуальній машині Google Cloud Platform (GCP).

Використані технології: **Docker, Docker Compose, Ansible, Certbot (Let's Encrypt), Nginx, GitHub Actions, Ansible Vault.**

## 🏗️ Архітектура та Середовища

Система налаштована для підтримки двох середовищ на одному сервері, контрольованих гілками Git:

|Середовище|Гілка Git|Домен|Захист та Health Check|
|---|---|---|---|
|**Production**|`main`|`prod.zepuff-test-task.pp.ua`|**HTTPS, Валідний Сертифікат, Basic Auth**|
|**Development**|`dev`|`dev.zepuff-test-task.pp.ua`|HTTPS (Ігнорує сертифікат)|

### Логіка CI/CD

1. **Тригер:** `git push` у гілки `main` або `dev` запускає GitHub Actions.
    
2. **Автентифікація:** GitHub Actions використовує **SSH-ключ** (`SSH_PRIVATE_KEY`) та **Ansible Vault** для доступу до VM і секретів.
    
3. **Деплой:** Скрипт **`deploy.sh`** викликає Ansible, передаючи змінну `target_env` (`prod` або `dev`).
    
4. **Health Check (Критично):** Після успішного деплою `deploy.sh` виконує перевірку:
    
    - **Prod (`main`):** Використовує `curl` з прапором `--fail` для перевірки **Валідності Сертифіката**, **HTTPS-доступності** та **Basic Authentication** одночасно.
        

## ⚙️ Налаштування Передумов та Секретів

### 1. Налаштування SSH для CI/CD

Для безпарольної автентифікації Ansible:

1. **Згенеруйте** пару SSH-ключів **без парольної фрази** (passphrase):
    
    ```
    ssh-keygen -t rsa -b 4096 -f ci_key
    ```
    
2. Додайте вміст публічного ключа (`ci_key.pub`) до **Metadata SSH** вашої VM в Google Cloud Console.
    
3. Оновіть `ansible/inventory`, вказавши ім'я користувача, створене GCP.
    

### 2. GitHub Secrets (Обов'язково)

Усі чутливі дані зберігаються в **GitHub Secrets** (Settings > Secrets > Actions):

|Назва Секрету|Формат|Призначення|
|---|---|---|
|**`SSH_PRIVATE_KEY`**|Вміст файлу `ci_key`|Приватний ключ для автентифікації.|
|**`ANSIBLE_VAULT_PASSWORD`**|Текст|Пароль для розшифрування `vault.yml`.|
|**`PROD_BASIC_AUTH`**|`user:password`|Облікові дані для Health Check Prod (Наприклад, `admin:mysecret`).|

### 3. Конфігурація Ansible для CI/CD

Файл **`ansible.cfg`** повинен бути розміщений у корені проєкту, щоб вимкнути перевірку ключів хоста (що є причиною помилки `Host key verification failed` у CI-раннерах).

```
[defaults]
host_key_checking = False
inventory = ./ansible/inventory
vault_password_file = .vault_pass
```

## 📄 Основні Файли Проєкту

### `deploy.sh`

Єдина точка входу, яка керує деплоєм та перевірками.

**Локальне тестування:**

Для тестування Prod-середовища необхідно експортувати облікові дані:

```
# Встановіть змінну перед запуском
export BASIC_AUTH_CREDENTIALS="myuser:mypassword"

# Запуск деплою
bash deploy.sh main ~/.vault_pass.txt
```

### `.github/workflows/main.yml`

Файл конфігурації CI/CD. Встановлює SSH-ключ та змінні оточення, включно з **ANSIBLE_HOST_KEY_CHECKING: 'false'** для надійної роботи.

## ⚠️ Усунення Несправностей (Troubleshooting)

| Помилка / Проблема                    | Причина                                             | Рішення                                                                                                                                                    |
| ------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`Host key verification failed`**    | Ansible не вимкнув перевірку ключів хоста.          | Переконайтеся, що файл `ansible.cfg` є у корені репозиторію АБО що змінна `ANSIBLE_HOST_KEY_CHECKING: 'false'` встановлена у `.github/workflows/main.yml`. |
| **`UNREACHABLE!`** (Ansible)          | Проблема з SSH-ключем або користувачем.             | Перевірте, чи коректно скопійовано `SSH_PRIVATE_KEY` у секрети та чи правильно вказано `ansible_user` в `inventory`.                                       |
| **`curl` повертає Код 22** (Prod)     | Збій Health Check, зазвичай через 401 Unauthorized. | Перевірте, чи секрет `PROD_BASIC_AUTH` коректно встановлений у GitHub Secrets.                                                                             |
| **`'branch' is undefined`** (Ansible) | У Playbook використовується стара змінна.           | Оновіть `ansible/playbook.yml`: замініть усі `branch` на `target_env`.                                                                                     |


'branch' is undefined (Ansible)

У Playbook використовується стара змінна.

Оновіть ansible/playbook.yml: замініть усі branch на target_env.
