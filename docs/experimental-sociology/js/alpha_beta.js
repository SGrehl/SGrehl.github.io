window.onload = function() {
  // Approximate error function for CDF
  function erf(x) {
    var a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741;
    var a4 = -1.453152027, a5 = 1.061405429, p = 0.3275911;
    var sign = x < 0 ? -1 : 1;
    x = Math.abs(x);
    var t = 1/(1 + p*x);
    var y = 1 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t*Math.exp(-x*x);
    return sign * y;
  }
  function normCDF(z) { return 0.5 * (1 + erf(z / Math.sqrt(2))); }
  function normalPDF(x, mean, sd) {
    return (1/(sd*Math.sqrt(2*Math.PI))) * Math.exp(-0.5 * Math.pow((x-mean)/sd,2));
  }

  // Precompute x-grid
  var x = Array.from({length:1000}, function(_,i){return -4 + i*0.01;});
  
  function invNorm(p) { return Math.sqrt(2)*erfInv(2*p-1); }
  // inverse erf
  function erfInv(x) {
    var a=0.147;
    var ln= Math.log((1-x)*(1+x));
    var part1=2/(Math.PI*a)+ln/2;
    var part2=1/a*ln;
    return (x>=0?1:-1)*Math.sqrt(Math.sqrt(part1*part1-part2)-part1);
  }
  
  // Main plot update
  function updatePlot() {
    var alpha = parseFloat(document.getElementById('a_value').value);
    var d = parseFloat(document.getElementById('d_value').value);
    var sd = parseFloat(document.getElementById('sd_value').value);
    var mu0 = 0, mu1 = d;

    // Update labels
    document.getElementById('a_value_label').innerText = alpha.toFixed(2);
    document.getElementById('d_value_label').innerText = d.toFixed(2);
    document.getElementById('sd_value_label').innerText = sd.toFixed(2);

    // Densities
    var y0 = x.map(function(v){return normalPDF(v,mu0,sd);});
    var y1 = x.map(function(v){return normalPDF(v,mu1,sd);});

    var z_crit = sd * Math.abs(invNorm(1-alpha/2));

    // Error rates
    var beta  = normCDF(z_crit/sd - (mu1-mu0)/sd);

    // Traces
    var traceH0 = {x:x,
                   y:y0,
                   mode:'lines',
                   name:'H₀ true',
                   line:{color:'blue'},
                   hoverinfo:'skip'
    };
    
    var traceH1 = {x:x,
                   y:y1,
                   mode:'lines',
                   name:'H₁ true',
                   line:{color:'red'},
                   hoverinfo:'skip'
    };

    // Type I areas
    var xL = x.filter(function(v){return v< -z_crit;});
    var yL = xL.map(function(v){return normalPDF(v,mu0,sd);});
    var areaL = {x:xL.concat([xL[xL.length-1],xL[0]]),y:yL.concat([0,0]),fill:'toself',fillcolor:'rgba(0,0,255,0.2)',line:{color:'transparent'},name:'α≈'+alpha.toFixed(3),hoverinfo:'skip',showlegend:false};
    
    var xR = x.filter(function(v){return v> z_crit;});
    var yR = xR.map(function(v){return normalPDF(v,mu0,sd);});
    var areaR = {x:xR.concat([xR[xR.length-1],xR[0]]),y:yR.concat([0,0]),fill:'toself',fillcolor:'rgba(0,0,255,0.2)',line:{color:'transparent'},name:'α≈'+alpha.toFixed(3),hoverinfo:'skip',showlegend:true};

    // Type II area
    var xB = x.filter(function(v){return v< z_crit;});
    var yB = xB.map(function(v){return normalPDF(v,mu1,sd);});
    var areaB = {x:xB.concat([xB[xB.length-1],xB[0]]),y:yB.concat([0,0]),fill:'toself',fillcolor:'rgba(255,0,0,0.2)',line:{color:'transparent'},name:'β≈'+beta.toFixed(3),hoverinfo:'skip',showlegend:true};

    // Layout
    var layout = {title:{text:'Alpha & Beta Errors'},
                  xaxis:{title:{text:'Critical Value z'}},
                  yaxis:{title:{text:'Density'}},
                  showlegend:true};

    Plotly.newPlot('power-plot',[traceH0,traceH1,areaL,areaR,areaB],layout,{staticPlot:true});
  }

  // Listeners
  ['a_value','d_value','sd_value'].forEach(function(id){
    document.getElementById(id).addEventListener('input',updatePlot);
  });

  // Initial draw
  updatePlot();
};