// ─────────────────────────────────────────────────────────────────────────────
// Global variables
let board;           // 2D array representing the board
let timerId = -1;    // -1 means timer is not active
let boardWidth;      // Number of cells per row/column
let round = 0;

// Agent constants
const AGENT_RED  = 'R';
const AGENT_BLUE = 'B';
const EMPTY_CHAR = ' ';

// Canvas and drawing context
let canvas, ctx;

// ─────────────────────────────────────────────────────────────────────────────
// When document is ready, wire up controls and initialize
$(document).ready(function() {
  // Cache canvas and context
  canvas = document.getElementById('boardCanvas');
  ctx    = canvas.getContext('2d');

  // Update the displayed slider values
  function updateSimilar() {
    $('#similar-value').html($('#similar').val());
  }
  updateSimilar();
  $('#similar').on('input', updateSimilar);

  $('#empty-value').html($('#empty').val());
  $('#empty').on('input', function() {
    $('#empty-value').html($('#empty').val());
  }).change(resetClick);

  function updateRedBlueValues() {
    const red = $('#red-blue').val();
    const blue = 100 - red;
    $('#red-blue-value').html(red + '/' + blue);
  }
  updateRedBlueValues();
  $('#red-blue').on('input', updateRedBlueValues).change(resetClick);

  function updateSize() {
    const size = $('#size').val();
    $('#size-value').html(size + 'x' + size);
  }
  updateSize();
  $('#size').on('input', updateSize).change(resetClick);

  function updateDelay() {
    const delay = $('#delay').val();
    $('#delay-value').html(delay);

    if (timerId != -1) {
      clearInterval(timerId);
      timerId = setInterval(doOneRound, delay);
    }
  }
  updateDelay();
  $('#delay').on('input', updateDelay);

  // Wire up buttons
  $('#start').click(startClick);
  $('#stop').click(stopClick);
  $('#step').click(stepClick);
  $('#reset').click(resetClick);

  // Initial draw
  resetClick();

  // Disable Stop initially
  $('#stop').attr('disabled', true);
});

// ─────────────────────────────────────────────────────────────────────────────
// Button callbacks
function startClick() {
  $('#start').attr('disabled', true);
  $('#stop').attr('disabled', false);

  if (timerId == -1) {
    timerId = setInterval(doOneRound, $('#delay').val());
  }
}

function stopClick() {
  $('#start').attr('disabled', false);
  $('#stop').attr('disabled', true);

  if (timerId != -1) {
    clearInterval(timerId);
  }
  timerId = -1;
}

function stepClick() {
  stopClick();
  doOneRound();
}

// ─────────────────────────────────────────────────────────────────────────────
// Reset: build a fresh board + draw initial state
function resetClick() {
  stopClick();

  boardWidth = parseInt($('#size').val(), 10);
  round = 0;
  $('#round').html(round);

  // Initialize 2D board array
  board = Array.from({ length: boardWidth }, () => Array(boardWidth).fill(EMPTY_CHAR));

  // Determine proportions
  const emptyRatio = $('#empty').val() / 100;
  const redRatio   = $('#red-blue').val() / 100;

  // Fill board randomly
  let index = 0;
  for (let r = 0; r < boardWidth; r++) {
    for (let c = 0; c < boardWidth; c++) {
      const rand = Math.random();
      if (rand < 1 - emptyRatio) {
        // Occupied: red with probability redRatio, else blue
        board[r][c] = (Math.random() < redRatio ? AGENT_RED : AGENT_BLUE);
      }
      else {
        board[r][c] = EMPTY_CHAR;
      }
      index++;
    }
  }

  setSatisfied(0);
  drawBoard();
}

// ─────────────────────────────────────────────────────────────────────────────
// Main simulation step: find unsatisfied, move them, then redraw
function doOneRound() {
  round++;
  $('#round').html(round);

  const unsatisfied = [];
  const blankCells  = [];

  // 1) Identify unsatisfied agents and blank cells
  for (let r = 0; r < boardWidth; r++) {
    for (let c = 0; c < boardWidth; c++) {
      if (board[r][c] === EMPTY_CHAR) {
        blankCells.push({ r, c });
      } else {
        if (!isSatisfied(r, c, board[r][c])) {
          unsatisfied.push({ r, c, agent: board[r][c] });
        }
      }
    }
  }

  // 2) Move each unsatisfied agent to a random blank cell
  unsatisfied.forEach(({ r, c, agent }) => {
    if (blankCells.length === 0) return; // no open spot left

    // Pick random blank cell
    const idx = Math.floor(Math.random() * blankCells.length);
    const { r: nr, c: nc } = blankCells[idx];

    // Swap
    board[nr][nc] = agent;
    board[r][c]     = EMPTY_CHAR;

    // Update blankCells: replaced slot is now occupied; old spot becomes blank
    blankCells.splice(idx, 1);
    blankCells.push({ r, c });
  });

  // 3) Recompute satisfaction percentage
  let totalAgents = 0;
  let numSatisfied = 0;
  for (let r = 0; r < boardWidth; r++) {
    for (let c = 0; c < boardWidth; c++) {
      if (board[r][c] === AGENT_RED || board[r][c] === AGENT_BLUE) {
        totalAgents++;
        if (isSatisfied(r, c, board[r][c])) {
          numSatisfied++;
        }
      }
    }
  }
  const percSatisfied = roundNumber((numSatisfied / totalAgents) * 100, 1);
  setSatisfied(percSatisfied);

  // 4) Redraw
  drawBoard();

  // 5) Stop if all satisfied
  if (numSatisfied === totalAgents) {
    stopClick();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Determine if agent at (row,col) is satisfied
function percentSimilar(row, col, agent) {
  let occupied = 0;
  let similar  = 0;

  for (let dr = -1; dr <= 1; dr++) {
    for (let dc = -1; dc <= 1; dc++) {
      if (dr === 0 && dc === 0) continue;
      const rr = row + dr;
      const cc = col + dc;
      if (rr >= 0 && rr < boardWidth && cc >= 0 && cc < boardWidth) {
        if (board[rr][cc] !== EMPTY_CHAR) {
          occupied++;
          if (board[rr][cc] === agent) {
            similar++;
          }
        }
      }
    }
  }
  return occupied === 0 ? 100 : (similar / occupied) * 100;
}

function isSatisfied(row, col, agent) {
  const threshold = parseFloat($('#similar').val());
  return percentSimilar(row, col, agent) >= threshold;
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility: round to given decimals
function roundNumber(number, digits) {
  const mult = Math.pow(10, digits);
  return Math.round(number * mult) / mult;
}

// ─────────────────────────────────────────────────────────────────────────────
// Update the “Satisfied” percentage display
function setSatisfied(val) {
  $('#satisfied').html(val + " %");
}

// ─────────────────────────────────────────────────────────────────────────────
// REDRAW ENTIRE BOARD ON CANVAS
function drawBoard() {
  // Clear canvas
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  // Determine cell size so that boardWidth × boardWidth fits canvas
  const cellSize = canvas.width / boardWidth;

  for (let r = 0; r < boardWidth; r++) {
    for (let c = 0; c < boardWidth; c++) {
      const x = c * cellSize;
      const y = r * cellSize;

      if (board[r][c] === AGENT_RED) {
        ctx.fillStyle = '#FF5555'; // red
      }
      else if (board[r][c] === AGENT_BLUE) {
        ctx.fillStyle = '#5555FF'; // blue
      }
      else {
        ctx.fillStyle = '#FFFFFF'; // empty = white
      }

      // Draw the cell background
      ctx.fillRect(x, y, cellSize, cellSize);

      // Draw cell border
      ctx.strokeStyle = '#CCCCCC';
      ctx.strokeRect(x, y, cellSize, cellSize);
    }
  }
}