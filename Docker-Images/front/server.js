const express = require("express");
const path = require("path");
const cors = require('cors');
const PROXY_API_URL_CPU = "http://cpu-bench-service:1500";
const PROXY_API_URL_MEM = "http://mem-bench-service:1500";


const app = express();
const PORT = 3000;
app.use(cors());

app.use(express.json());
app.use(express.static(path.join(__dirname, "src")));

app.get("/", (req, res) => {
  res.send("This is the home of the front application");
});

app.get("/cpu", express.json(), async (req, res) => {
  try {
    const response = await fetch(PROXY_API_URL_CPU);
    const data = await response.json();
    res.json(data);
  } catch (err) {
    console.error("Error in /cpu:", err);
    res.status(500).send("Error processing request");
  }
});

app.get("/mem", express.json(), async (req, res) => {
  try {
    const response = await fetch(PROXY_API_URL_MEM);
    const data = await response.json();
    res.json(data);
  } catch (err) {
    console.error("Error in /mem:", err);
    res.status(500).send("Error processing request");
  }
})

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});