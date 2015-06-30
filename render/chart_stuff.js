
function addLabel( eventEmitter, useForeignObject, positionalData, group, classes, axis, index, label, type ) {
  var labelElement;
  if( useForeignObject ) {
    var content = '<span class="' + classes.join(' ') + '">' + label + '</span>';
    labelElement = group.foreignObject( 
      content,
      Chartist.extend( 
        {
          style: 'overflow: visible;'
        },
        positionalData
      )
    );
  } 
  else {
    if( type == 'Y' ) {
      var x = positionalData.x;
      var y = positionalData.y;
      positionalData.transform = 'translate('+x+','+y+')rotate(90)translate('+(-x)+','+(-y)+')';
      labelElement = group.elem('text', positionalData, classes.join(' ')+' vertical').text( label );
      var node = labelElement._node;
      //var x = node.x.baseVal[0].value;
      //var y = node.y.baseVal[1].value;
      //node.setAttribute('transform',  );
    }
    else {
      labelElement = group.elem('text', positionalData, classes.join(' ')).text( label );
    }
  }
  
  eventEmitter.emit('draw', Chartist.extend({
    type: 'label',
    axis: axis,
    index: index,
    group: group,
    element: labelElement,
    text: label
  }, positionalData));
}
function getTextWidth(text, font) {
    // re-use canvas object for better performance
    var canvas = getTextWidth.canvas || (getTextWidth.canvas = document.createElement("canvas"));
    var context = canvas.getContext("2d");
    //context.font = font;
    var metrics = context.measureText(text);
    return metrics.width;
};
Chartist.createAxisLabel = function( axis, axisOffset, labelOffset, group, eventEmitter, options, type, optionsg ) {
  var projectedValue = {
    pos: 0,
    len: 0
  };
  var positionalData = {};
  positionalData[axis.units.pos] = projectedValue.pos + labelOffset[axis.units.pos];
  positionalData[axis.counterUnits.pos] = labelOffset[axis.counterUnits.pos];
  positionalData[axis.units.len] = projectedValue.len + 50; // + 50 allows a label to go past it's column
  positionalData[axis.counterUnits.len] = axisOffset;
  
  var label = options.label;
  var textWidth = getTextWidth( label );
  
  if( type == 'Y' ) {
    positionalData[axis.units.pos] += ( optionsg.height/2) - textWidth/2; // move down so it's visible on the left
  }
  else {
    positionalData[axis.units.pos] += ( optionsg.width /2) - textWidth/2 ; // move to the right
    positionalData[axis.counterUnits.pos] += 40; // move down under other labels
  }
  
  var useForeignObject = 0;
  var classes = [];
  
  var index = 0;
  addLabel( eventEmitter, useForeignObject, positionalData, group, classes, axis, index, label, type );
}
Chartist.createLabel = function(projectedValue, index, labels, axis, axisOffset, labelOffset, group, classes, useForeignObject, eventEmitter) {
  var positionalData = {};
  positionalData[axis.units.pos] = projectedValue.pos + labelOffset[axis.units.pos];
  positionalData[axis.counterUnits.pos] = labelOffset[axis.counterUnits.pos];
  positionalData[axis.units.len] = projectedValue.len + 50; // + 50 allows a label to go past it's column
  positionalData[axis.counterUnits.len] = axisOffset;
  
  var label = labels[ index ];
  
  if( label.indexOf && label.indexOf("\n") != -1 ) {
    var lines = label.split("\n");
    for( var i in lines ) {
      var line = lines[i];
      addLabel( eventEmitter, useForeignObject, positionalData, group, classes, axis, index, line, 'X' );
      positionalData[ axis.counterUnits.pos ] += 17;
    }
  }
  else addLabel( eventEmitter, useForeignObject, positionalData, group, classes, axis, index, label, 'X' );
};


function ctPointLabels(options) {
  return function ctPointLabels(chart) {
    var defaultOptions = {
      labelClass: 'ct-label',
      labelOffset: {
        x: 0,
        y: -10
      },
      textAnchor: 'middle'
    };

    options = Chartist.extend({}, defaultOptions, options);

    if(chart instanceof Chartist.Line) {
      chart.on('draw', function(data) {
        if(data.type === 'point') {
          data.group.elem('text', {
            x: data.x + options.labelOffset.x,
            y: data.y + options.labelOffset.y,
            style: 'text-anchor: ' + options.textAnchor
          }, options.labelClass).text(data.value);
        }
      });
    }
  }
}
function std_colors( i ) {
  var colors = [
      [128,166,212],
      [253,133,175],
      [255,156,90],
      [101,198,124],
      [90,204,194],
      [84,199,239],
      [255,194,103],
      [255,128,129]
  ];
  var col = [];
  for( var j in colors ) {
    var color = colors[j];
    col.push( 'rgb('+color[0]+','+color[1]+','+color[2]+')' );
  }
  return col[ i ] || 'rgb(192,192,192)';
}


function fix_numbers( hash ) {
  var dud = {};
  for( var i in hash ) {
    if( i in dud ) continue;
    var v = hash[i];
    if( typeof( v ) == 'object' ) fix_numbers( v );
    if( v == 'true' ) v = true;
    else if( v*1 == v ) v = v * 1;
    hash[ i ] = v;
  }
}

function _mux( a, b ) {
  var dud = {};
  for( var i in b ) {
    if( i in dud ) continue;
    var v = b[i];
    a[ i ] = v;
  }
}