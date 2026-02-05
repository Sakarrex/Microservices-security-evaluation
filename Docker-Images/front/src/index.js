const URL_INGRESS = "/api";
const form = document.querySelector("form");

form.addEventListener("submit", (e) => {
  e.preventDefault();
  callBackend();
});

async function callBackend() {
  const num1 = document.getElementById("fnum").value;
  const num2 = document.getElementById("snum").value;
  const result = document.getElementById("result");
  try {
    const response = await fetch(URL_INGRESS, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        
      },
      body: JSON.stringify({
        num1: num1,
        num2: num2
      })
    });
    const text = await response.text();
    result.innerText = `La suma es: ${text}`;
  } catch (err) {
    console.error("Error:", err);
  }
}
