# 1. Вибираємо базовий образ Node.js
FROM node:18-alpine

# 2. Встановлюємо робочу директорію всередині контейнера
WORKDIR /usr/src/app

# 3. Копіюємо файли package.json та package-lock.json
COPY package*.json ./

# 4. Встановлюємо залежності
RUN npm install

# 5. Копіюємо решту файлів додатку (наш server.js)
COPY . .

# 6. Вказуємо порт, який буде слухати додаток
EXPOSE 3000

# 7. Команда для запуску додатку
CMD [ "node", "server.js" ]