const readline = require("readline");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function calculateSurfaceArea(radius) {
  const pi = Math.PI;
  let Area = pi * Math.pow(radius, 2);
  console.log(`${Area.toFixed(2)}`);
}

rl.question("Enter the radius: ", (radius) => {
  radius = parseFloat(radius);

  if (isNaN(radius) || radius <= 0) {
    console.log("Please enter a valid positive number for the radius.");
  } else {
    calculateSurfaceArea(radius);
  }

  rl.close();
});
