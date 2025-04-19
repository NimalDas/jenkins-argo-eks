const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.json({ message: 'Hello, World! Version 1', version: 'v1' });
});

app.listen(port, () => {
  console.log(`App running on http://localhost:${port}`);
});