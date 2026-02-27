const express = require("express");
const path = require("path");
const cors = require('cors');
const { exec } = require('child_process');

const app = express();
const PORT = 3000;
const filePath = './program';
app.use(cors());

app.use(express.json());
app.use((req, _res, next) => {
  req.token = req.headers.authorization;
  next();
});

app.get("/", express.json(), (req, res) => {
    console.log(req.headers);
    exec(`"${filePath}"`, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error opening .exe file: ${error}`);
            res.status(500).send('Error opening .exe file');
            return;
        }
        res.send(JSON.stringify(stdout));
    });
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});