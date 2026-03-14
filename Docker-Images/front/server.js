const express = require("express");
const path = require("path");
const cors = require('cors');

const PROXY_API_URL_CPU = "http://cpu-bench-service:3000";
const PROXY_API_URL_MEM = "http://mem-bench-service:3000";
const PORT = 3000;

const app = express();
app.use(cors());

app.use(express.json());
app.use(express.static(path.join(__dirname, "src")));
app.use((req, _res, next) => {
  req.token = req.headers.authorization;
  next();
});

app.get("/", (req, res) => {
  res.send("This is the home of the front application");
});

app.get("/cpu", express.json(), async (req, res) => {
  try {
    const response = await fetch(PROXY_API_URL_CPU,{
      headers: {
        "Authorization": `${req.token}`
      }
    });
    const data = await response.json();
    res.json(data);
  } catch (err) {
    console.error("Error in /cpu:", err);
    res.status(500).send("Error processing request");
  }
});

app.get("/mem", express.json(), async (req, res) => {
  try {
    const response = await fetch(PROXY_API_URL_MEM,{
      headers: {
        "Authorization": `${req.token}`
      }
    });
    console.log("Response from mem-bench:", response);
    const data = await response.json();
    res.json(data);
  } catch (err) {
    console.error("Error in /mem:", err);
    res.status(500).send("Error processing request");
  }
})

app.get("/run", express.json(), async (req, res) => {
  try {
    const responseMem = await fetch(PROXY_API_URL_MEM,{
      headers: {
        "Authorization": `${req.token}`
      }
    });
    const responseCpu = await fetch(PROXY_API_URL_CPU,{
      headers: {
        "Authorization": `${req.token}`
      }
    });
    const dataMem = await responseMem.json();
    const dataCpu = await responseCpu.json();
    res.json({ mem: dataMem, cpu: dataCpu });
  } catch (err) {
    console.error("Error in /cpu or /mem:", err);
    res.status(500).send("Error processing request");
  }
})

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});