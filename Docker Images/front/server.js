const express = require("express");
const path = require("path");
const cors = require('cors');
const PROXY_API_URL = "http://back-service:1500/api";

const app = express();
const PORT = 3000;
app.use(cors());

app.use(express.json());
app.use(express.static(path.join(__dirname, "src")));

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "src", "index.html"));
});

app.post("/api", express.json(), async (req, res) => {
  try {
    const response = await fetch(PROXY_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        num1: req.body.num1,
        num2: req.body.num2
      })
    });
    const data = await response.json();
    res.json(data);
  } catch (err) {
    console.error("Error en /api:", err);
    res.status(500).send("Error processing request");
  }
});

app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});