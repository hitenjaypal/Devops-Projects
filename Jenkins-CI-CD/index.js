const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello from Node.js! This is a simple app for Jenkins CI/CD pipeline.');
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
