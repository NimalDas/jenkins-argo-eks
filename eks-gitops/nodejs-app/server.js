const express = require('express');
const app = express();
const port = 3000;

const version = process.env.DEPLOYMENT_VERSION || 'v1';
const bgColor = version.startsWith('v1') ? 'blue' : 'green';

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Node.js Blue-Green Demo</title>
      <style>
        body { 
          background-color: ${bgColor}; 
          color: white; 
          font-family: Arial, sans-serif; 
          display: flex; 
          justify-content: center; 
          align-items: center; 
          height: 100vh; 
          margin: 0;
        }
        h1 { text-align: center; }
      </style>
    </head>
    <body>
      <h1>Hello, World! ${version} (${bgColor} deployment)</h1>
    </body>
    </html>
  `);
});

app.listen(port, () => {
  console.log(`App running on http://localhost:${port}`);
});