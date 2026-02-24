const express = require("express");
const path = require("path");
const cors = require('cors');


const app = express();
const PORT = 3000;
app.use(cors());

app.use(express.json());

function multiply(matrix1, matrix2, N) {
  let result = new Array(N).fill(0).map(() => new Array(N).fill(0));
  for (let i = 0; i < N; i++) {
    for (let j = 0; j < N; j++) {
      let sum = 0;
      for (let k = 0; k < N; k++) {
        sum += matrix1[i][k] * matrix2[k][j];
      }
      result[i][j] = sum;
    }
 }
 return result;
}

app.get("/", express.json(), (req, res) => {
  let N =  10 + Math.floor(Math.random() * 90);
  let matrix1 = new Array(N).fill(0).map(() => new Array(N).fill(0).map(() => Math.floor(Math.random() * 10)));
  let matrix2 = new Array(N).fill(0).map(() => new Array(N).fill(0).map(() => Math.floor(Math.random() * 10)));
  let result = multiply(matrix1, matrix2, N);
  console.log(`Multiplied two ${N}x${N} matrices`);
  res.send(JSON.stringify(result));
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});