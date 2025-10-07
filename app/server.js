const express = require('express');
const app = express();
const port = 3000; // Порт, на якому буде працювати додаток всередині Docker

// Головний маршрут, який віддає HTML-сторінку
app.get('/', (req, res) => {
  // Зчитуємо колір з енварернмент-змінної. Якщо її немає, буде білий.
  const bgColor = process.env.APP_BG_COLOR || 'white';

  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Hello App</title>
        <style>
            body {
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                font-family: sans-serif;
                background-color: ${bgColor}; /* Тут використовується наша змінна */
            }
            h1 {
                color: white;
                font-size: 5em;
                text-shadow: 2px 2px 4px #000000;
            }
        </style>
    </head>
    <body>
        <h1>Hello Dev</h1>
    </body>
    </html>
  `;

  res.send(htmlContent);
});

app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});
