var Class={
create:function(){
return function(){
this.initialize.apply(this,arguments);
}
}
};
var Prototype={
emptyFunction:function(){}
};
var Try={
these:function(){
var $B;
for(var i=0;i<arguments.length;i++){
var lambda=arguments[i];
try{
$B=lambda();
break;
}catch(e){}
}
return $B;
}
};
function arg2A($A){
var ar=[];
for(var i=0;i<$A.length;i++){
ar.push($A[i]);
}
return ar;
}
Function.prototype.bind=function(){
var __method=this,
args=arg2A(arguments),
object=args.shift();
return function(){
return __method.apply(object,args.concat(arg2A(arguments)));
}
}
