$(function () {
  const canvasUnits = 10;
  const n_points = 10000;
  const canvas = document.getElementById("simulationCanvas");
  const ctx = canvas.getContext("2d");
  const scale = canvas.width / canvasUnits;

  function drawSimulation(width, height) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = "black";
    ctx.strokeRect(0, 0, canvas.width, canvas.height);

    let insideCount = 0;
    for (let i = 0; i < n_points; i++) {
      let x = Math.random() * canvasUnits;
      let y = Math.random() * canvasUnits;
      let isInside = x <= width && y <= height;
      if (isInside) insideCount++;

      ctx.beginPath();
      ctx.arc(x * scale, canvas.height - y * scale, 1.5, 0, 2 * Math.PI);
      ctx.fillStyle = isInside ? "blue" : "red";
      ctx.fill();
    }

    // Draw rectangle outline
    ctx.strokeStyle = "green";
    ctx.lineWidth = 2;
    ctx.strokeRect(0, canvas.height - height * scale, width * scale, height * scale);

    const estimatedArea = (insideCount / n_points) * 100;
    const trueArea = width * height;

    $("#results").html(
      `<strong>Estimated Area:</strong> ${estimatedArea.toFixed(2)}<br>
       <strong>True Area:</strong> ${trueArea.toFixed(2)}<br>
       <strong>Points Inside:</strong> ${insideCount}/${n_points}`
    );
  }

  $("#StartMC").on("click", function () {
    const width = parseFloat($("#rectWidth").val());
    const height = parseFloat($("#rectHeight").val());

    if (width < 0 || width > 10 || height < 0 || height > 10) {
      alert("Please enter values between 0 and 10.");
      return;
    }

    drawSimulation(width, height);
  });
});