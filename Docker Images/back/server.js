const express = require("express");
const path = require("path");
const cors = require('cors');


const app = express();
const PORT = 3000;
app.use(cors());

app.use(express.json());
app.use(express.static(path.join(__dirname, "src")));


app.post("/api", express.json(), (req, res) => {
  const { num1, num2 } = req.body;
  const sum = Number(num1) + Number(num2);
  res.send(sum.toString());
});

app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});