function _xmlquery(){
var t=arguments[1].split(' ').join('=?&')+'=?',i=-1,l=-1,k=1,o='',a,e,v,j;
while((i=t.indexOf('?',i+1))>=0){a=t.substring(l+1,i);v=arguments[++k];j=0
;if(a.substr(0,++j)=='-'||a.substr(0,++j)=='&-'){a=(j>1?'&':'')+a.substr(j);
v=escape(v)}o+=a+v;l=i}o+=t.substr(l+1);
var a=new Ajax(_CGI.substr(0,_CGI.length-1),{postBody:o,onSuccess:arguments[0],toOb:1});
}
function _query(){
var t=arguments[0].split(' ').join('=?&')+'=?',i=-1,l=-1,k=0,o='',a,e,
v,j;while((i=t.indexOf('?',i+1))>=0){a=t.substring(l+1,i);v=arguments[
++k];j=0;if(a.substr(0,++j)=='-'||a.substr(0,++j)=='&-'){a=(j>1?'&':''
)+a.substr(j);v=escape(v)}o+=a+v;l=i}return o+=t.substr(l+1)
}
Ajax=Class.create();
Ajax.Events=['Uninitialized','Loading','Loaded','Interactive','Complete'];
Ajax.prototype={
initialize:function($N,$D){
this.transport=this.getTransport();
this.options=$D;
this.transport.open(this.options.postBody?'post':'get',$N,true);
this.transport.onreadystatechange=this.onStateChange.bind(this);
this.setRequestHeaders();
this.transport.send($D.postBody? $D.postBody:null);
},
getTransport:function(){
return Try.these(
function(){return new ActiveXObject('Msxml2.XMLHTTP')},
function(){return new ActiveXObject('Microsoft.XMLHTTP')},
function(){return new XMLHttpRequest()}
)||false;
},
setRequestHeaders:function(){
var $headers=['X-Requested-With','XMLHttpRequest',
'X-Prototype-Version','Protocut Version 0.1',
'Content-type','application/x-www-form-urlencoded'];
if(this.transport.overrideMimeType)$headers.push('Connection','close');
while($headers.length)this.transport.setRequestHeader($headers.shift(),$headers.shift());
},
onStateChange:function(){
var $B=Ajax.Events[this.transport.readyState];
if($B=='Complete'){
this.callback(this.transport.status,this.responseIsSuccess()?'Success':'Failure');
this.callback($B);
this.transport.onreadystatechange=Prototype.emptyFunction;
}
else this.callback($B);
},
callback:function($S,$T){
var $a=this;
if(this.options.toOb)$a=xml2obj(this.transport.responseXML).xml;
var $g='on'+$S,$A=this.options[$g];
if($A){$A($a);return;}
if(!$T)return;
var $h='on'+$T,$C=this.options[$h];
if($C)$C($a);
},
responseIsSuccess:function(){
var $F=this.transport.status;
if(!$F)return 1;
if($F>=200&&$F<300)return 1;
return 0;
}
}
var _multi='nodename';
function xml2obj($L){
var $c={},$H={},$G=[];
if( $L == null ) return $c;
if($L.attributes){
if($L.attributes.length){
for(var k=0;k<$L.attributes.length;k++){
var ob={};
$c[$L.attributes[k].nodeName]=ob;
ob.value=$L.attributes[k].nodeValue;
ob.att=1;
}
}
}
if(allTextChildren($L)){
$c.value='';
for(var i=0;i<$L.childNodes.length;i++){
var $R=$L.childNodes[i];
$c.value+=$R.nodeValue;
}
$c.value=_decode($c.value);
}
else if($L.childNodes.length){
var $R,$O='';
for(var i=0;i<$L.childNodes.length;i++){
$R=$L.childNodes[i];
if($R.nodeType==4)$O=$R.nodeValue;
if($R.nodeType!=1)continue;
if(!$H[$R.nodeName]){
$H[$R.nodeName]=new Array;
$G.push($R.nodeName);
}
$H[$R.nodeName].push($R);
}
if($O){
$c.value=$O;
$c.value=_decode($c.value);
}
else for(var i=0;i<$G.length;i++){
var $Y=$G[i],$I=$H[$Y].length;
if($I>1||$H['multi_'+$Y]||_multi==$Y){
$c[$Y]=[];
for(var i2=0;i2<$I;i2++){
$c[$Y].push(xml2obj($H[$Y][i2]));
}
}
else{
$c[$Y]=xml2obj($H[$Y][0]);
}
}
}
return $c;
}
function allTextChildren($Q){
if(!$Q.childNodes)return 0;
if(!$Q.childNodes.length)return 0;
for(var i=0;i<$Q.childNodes.length;i++){
if($Q.childNodes[i].nodeType!=3)return 0;
}
return 1;
}
function obj2xml($W,$Y,$e){
$e=$e? $e+1:1;
var $M='',$Z='';
if(!$W)return'';
for(var i in $W){
var $b=typeof($W[i]),$X=($b=='string'),$P=($b=='object'),$E=($W[i].length&&$P);
if($E){
for(var j=0;j<$W[i].length;j++){
$M+=obj2xml($W[i][j],i,$e-2);
}
$M+=_dup(' ',$e-2);
}
else if($X){
if(i=='value'){
var $f=$W[i];
$f=_encode($f);
$M+=$f;
}
else $M+='<'+i+'>'+$W[i]+'</'+i+'>';
}
else if($P){
if($W[i].att){
$Z+=' '+i+'="'+$W[i].value+'"';
}
else{
$M+=obj2xml($W[i],i,$e);
}
}
}
if(name){
$M=($e!=2? "\n":'')+_dup(' ',$e-2)+'<'+$Y+$Z+'>'+$M;
if($P)$M+="\n"+_dup(' ',$e-2);
$M+='</'+$Y+'>';
}
return $M;
}
function _dup($f,$I){
var $i='';
for(var i=0;i<$I;i++){
$i+=val;
}
return $i;
}
function _newval($f){
return{value:$f};
}
function _newatt($f){
return{att:1,value:$f};
}
function loadfile($V,$d){
var a=new Ajax($V,{onComplete:$d,toOb:1});
}
function newxml($K){
var ob;
if(window.ActiveXObject){
ob=new ActiveXObject("Microsoft.XMLDOM");
ob.async="false";
ob.loadXML($K);
}
else{
var parser=new DOMParser();
ob=parser.parseFromString($K,"text/xml");
}
return xml2obj(ob).xml;
}
function _decode($K){
return $K.replace(/&([#a-z0-9]{3,6});/g,_dec);
}
function _dec($J,$U){
switch($U){
case'deg':return'°';
case'frac14':return'¼';
case'frac12':return'½';
case'frac34':return'¾';
case'ldquo':return'“';
case'rdquo':return'”';
case'lsquo':return'‘';
case'rsquo':return'’';
default:return $J;
}
}
function _encode($K){
return'<![CDATA['+$K.replace(/[;°¼½¾“”‘’]/g,_enc)+']]>';
return $K.replace(/[°¼½¾“”‘’]/g,_enc);
}
function _enc($J){
switch($J){
case'°':return'&deg;';
case'¼':return'&frac14;';
case'½':return'&frac12;';
case'¾':return'&frac34;';
case'“':return'&ldquo;';
case'”':return'&rdquo;';
case'‘':return'&lsquo;';
case'’':return'&rsquo;';
default:return $J;
}
}
