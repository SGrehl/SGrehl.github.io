let board;           // 2D array used to represent game board
let timerId = -1;    // -1 means timer is not active

let boardWidth;      // Number of agents in the width (board width and height are the same)
let totalAgents = 0;
let round = 0;

const AGENT_RED = 'R';
const AGENT_BLUE = 'B';

$(document).ready(function() {
	
	function updateSimilar() {
		$('#similar-value').html($('#similar').val());
	}	

	updateSimilar();
	$('#similar').on('input', updateSimilar);	
	
	$('#empty-value').html($('#empty').val());
	
	$('#empty').on('input', function() {
		$('#empty-value').html($('#empty').val());		
	});
	
	$('#empty').change(resetClick);
	
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
		// Change delay between rounds
		const delay = $('#delay').val();
		$('#delay-value').html(delay);
		
		// Reset delay if timer is currently running
		if (timerId != -1) {
			clearInterval(timerId);
			const delay = $('#delay').val();			
			timerId = setInterval(doOneRound, delay);
		}
	}
	
	updateDelay();
	$('#delay').on('input', updateDelay);
	
	$('#start').click(startClick);
	$('#stop').click(stopClick);
	$('#step').click(stepClick);
	$('#reset').click(resetClick);
	
	// Create the board
	resetClick();
	
	// Can't press Stop until Start is pressed
	$('#stop').attr('disabled', true);	
});

function startClick() {
	$('#start').attr('disabled', true);
	$('#stop').attr('disabled', false);
	
	if (timerId == -1) {
		const delay = $('#delay').val();
		timerId = setInterval(doOneRound, delay);
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

function sum(r, c, search) {
	let total = 0;
	total += (r-1 >= 0 && c-1 >= 0 && board[r-1][c-1] == search) ? 1 : 0;
	total += (r-1 >= 0 && board[r-1][c] == search) ? 1 : 0;
	total += (r-1 >= 0 && c+1 < boardWidth && board[r-1][c+1] == search) ? 1 : 0;
	total += (c-1 >= 0 && board[r][c-1] == search) ? 1 : 0;
	total += (c+1 >= 0 && board[r][c+1] == search) ? 1 : 0;
	total += (c-1 >= 0 && r+1 < boardWidth && board[r+1][c-1] == search) ? 1 : 0;
	total += (r+1 < boardWidth && board[r+1][c] == search) ? 1 : 0;
	total += (c+1 < boardWidth && r+1 < boardWidth && board[r+1][c+1] == search) ? 1 : 0;
	
	return total;
}

function percentSimilar(row, col, agent) {
	// Return the percentage of adjacent nodes that are similar to the agent
	// Similar % = total like agent / occupied adjacent nodes
	
	let occupied = 0;
	let similar = 0;
	
	for (let r = row - 1; r <= row + 1; r++) {
		for (let c = col - 1; c <= col + 1; c++) {
			if (r == row && c == col) continue;			
				
			if (r >= 0 && r < boardWidth && c >= 0 && c < boardWidth) {
				if (board[r][c] != ' ') {
					occupied++;
					if (board[r][c] == agent)
						similar++;
				}
			}
		}
	}
	
	if (occupied == 0) {
		return 100;
	}
	else {
		return (similar / occupied) * 100;	
	}
}

function testPercentSimilar() {
	for (let r = 0; r < boardWidth; r++) {
		for (let c = 0; c < boardWidth; c++) {
			sim = percentSimilar(r, c, board[r][c]);
			//console.log(sim + ' % similar at (' + r + ',' + c + ')');
		}
	}
}

function isSatisfied(row, col, agent) {
	const similar = $('#similar').val();
	//var totalSimilar = sum(row, col, agent);
	//console.log('totalSimilar = ' + totalSimilar);
	
	const sim = percentSimilar(row, col, agent);
	return (similar <= sim);
}

// Move to a random cell that is nearest and available
function moveToNearest(row, col) {
	// Find nearest location to move which makes agent satisfied
	let radius = 1;
	let satisfied = false;
	let agent = board[row][col];
	let oppAgent = agent == AGENT_RED ? AGENT_BLUE : AGENT_RED;
	
	while (!satisfied && radius < boardWidth) {
		// Look in all adjacent cells above, bottom, right, left
		let r = row - 1;
		if (r >= 0) {
			for (let c = col - 1; c <= col + 1; c++) {
				if (board[r][c] == ' ')	{
					// See if this location will satisfy agent
					if (isSatisfied(r, c, agent)) {
						board[r][c] = agent;
						board[row][col] = ' ';
						return;
					}
				}					
			}
		}
		
		// Right
		c = col + 1;
		r = row;
		if (c < boardWidth) {
			if (board[r][c] == ' ')	{
				// See if this location will satisfy agent
				if (isSatisfied(r, c, agent)) {
					board[r][c] = agent;
					board[row][col] = ' ';
					return;
				}
			}
		}
		
		// Below (right to left)
		r = row + 1;
		if (r < boardWidth)	{
			for (c = col + 1; c >= col - 1; c++) {
				if (board[r][c] == ' ')	{
					// See if this location will satisfy agent
					if (isSatisfied(r, c, agent)) {
						board[r][c] = agent;
						board[row][col] = ' ';
						return;
					}
				}					
			}
		}
		
		// Left
		c = col - 1;
		r = row;
		if (c >= 0)	{
			if (board[r][c] == ' ')	{
				// See if this location will satisfy agent
				if (isSatisfied(r, c, agent)) {
					board[r][c] = agent;
					board[row][col] = ' ';
					return;
				}
			}
		}		
	}
}


// Move to random cell that is available, regardless of whether it satisfies
function moveToRandom(row, col, $blankCells) {
	const agent = board[row][col];
	const agentClass = agent == AGENT_RED ? 'red' : 'blue';

	const numCells = $blankCells.length;

	// Get random number between 0 and length-1
	const rand = Math.floor(Math.random() * numCells);

	const toCell = $blankCells[rand];
	const id = $(toCell).attr('id');
	const pos = parseInt(id.substr(3));
	
	// Convert position to [row][col]
	const destRow = Math.floor(pos / boardWidth);
	const destCol = pos % boardWidth;
	
	board[destRow][destCol] = agent;
	board[row][col] = ' ';
	
	// Convert [row][col] to position
	const newPos = boardWidth * row + col;
	
	//var fromCell = $('.cell')[pos];
	const fromId = '#pos' + newPos;
	const $fromCell = $(fromId);
	
	// Change blank cell to agent and vice versa
	$(toCell).removeClass('blank').addClass(agentClass);
	$fromCell.removeClass(agentClass).addClass('blank');
	
	// Add new blank cell and remove occupied cell 
	$blankCells.push($fromCell);
	$blankCells.splice(rand, 1);
	
}

function setSatisfied(percSatisfied) {
	$('#satisfied').html(percSatisfied + " %");
}

function stepClick() {	
	// Kill timer if it's running
	stopClick();
	
	doOneRound();
}

// Find all unsatisfied agents
function getUnsatisfiedAgents($allAgents) {
	
	//const $unsatisfied = $('.blue').add('.red').filter(function(index) {
	const $unsatisfied = $allAgents.filter(function(index) {
	
		// Get ID and use it to calc row and col 
		const pos = parseInt(this.getAttribute("id").substr(3));
		//console.log("pos = " + pos);
		
		const row = Math.floor(pos / boardWidth);
		const col = pos % boardWidth;
		if (isSatisfied(row, col, board[row][col])) {
			//console.log("(" + row + "," + col + ") is satisfied");
			return false;
		}
		else {
			//console.log("(" + row + "," + col + ") is NOT satisfied");
			return true;
		}
	});
	
	return $unsatisfied;
}

function doOneRound() {
	round++;
	$('#round').html(round);
	
	const $allAgents = $('.blue').add('.red');
	let $unsatisfied = getUnsatisfiedAgents($allAgents);
	
	// Move each unsatisfied agent to a randomly chosen empty location 
	// on the board, regardless of whether it satisfies them or not
	
	const $blankCells = $('td.blank');
	$unsatisfied.each(function(index) {
		// Get ID and use it to calc row and col 
		const pos = parseInt(this.getAttribute("id").substr(3));
		
		const row = Math.floor(pos / boardWidth);
		const col = pos % boardWidth;
		
		moveToRandom(row, col, $blankCells);		
	});
	
	// Find new number of unsatisfied agents after previously unsatisfied agents have moved
	$unsatisfied = getUnsatisfiedAgents($allAgents);
	const numSatisfied = $allAgents.length - $unsatisfied.length;
	const percSatisfied = roundNumber(numSatisfied / $allAgents.length * 100, 1);
	setSatisfied(percSatisfied);
	
	// Are all agents satisfied? Then stop the simulation.
	if (numSatisfied == $allAgents.length) {
		stopClick();
	}

}

function roundNumber(number, digits) {
	var multiple = Math.pow(10, digits);
	var rndedNum = Math.round(number * multiple) / multiple;
	return rndedNum;
}


function resetClick()
{
	// Stop the timer if it's running
	stopClick();
		
	// Create the board
	resize();
	
	round = 0;
	$('#round').html(round);
		
	// Create 2D array to represent board
	board = new Array(boardWidth);
	for (let i = 0; i < boardWidth; i++) {
		board[i] = new Array(boardWidth);
	}
	
	const $cells = $('td.cell');	
	
	$cells.removeClass().addClass('cell');
	
	// Calculate what percentage of cells should be empty
	let empty = 1 - ($('#empty').val() / 100);
	
	totalAgents = 0;
	
	let red;
	if ($('#red').length === 0) {
		red = $('#red-blue').val() / 100;
	}
	else {
		red = $('#red').val() / 100;
	}
	 
		
	let index = 0;
	for (let r = 0; r < boardWidth; r++) {
		for (let c = 0; c < boardWidth; c++) {			
			let rand = Math.random();
			if (rand < empty) {
				rand = Math.random();
				if (rand < red) {
					$($cells[index]).addClass('red');
					val = 'R';					
				}
				else {
					$($cells[index]).addClass('blue');
					val = 'B';
				}
				totalAgents++;
			}
			else {
				val = ' ';
				$($cells[index]).addClass('blank');
			}
				
			board[r][c] = val;
			//console.log(r + ", " + c + " = " + val);
			
			index++;
		}
	}
	
	setSatisfied(0);
}


function resize() {
	// Make board	
	boardWidth = $('#size').val();
	let htmlString = '';
	let index = 0;
	for (let r = 0; r < boardWidth; r++) {
		htmlString += "<tr>";
		for (let c = 0; c < boardWidth; c++) {
			htmlString += '<td class="cell" id="pos' + index + '"></td>\n';
			index++;
		}
		htmlString += "</tr>";
	}
		
	$('table.board').html(htmlString);
}