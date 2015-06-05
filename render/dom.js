function _enable(){
var len=arguments.length;
for(var i=0;i<len;i++){
var el=arguments[i];
if(el.isicon){
el.src=el.iconsrc;
el.style.cursor='pointer';
if(el.tip){
el.onmouseover=_tooltip.bind(el);
el.onmouseout=_endtooltip.bind(el);
}
}
else el.disabled=false;
}
}
function _disable(){
var len=arguments.length;
for(var i=0;i<len;i++){
var el=arguments[i];
if(el.isicon){
el.src='/template/contest/imgs/blankicon.gif';
el.style.cursor='default';
if(el.tip){
el.onmouseover=0;
el.onmouseout=0;
}
}
else arguments[i].disabled=true;
}
}
function _toggle(){
var len=arguments.length;
for(var i=0;i<len;i++){
var el=arguments[i];
if(el.disabled=='true')_enable(el);
else _disable(el);
}
}
function _hide($Y){
$Y.style.visibility='hidden';
$Y.style.display='none';
}
function _show($Y,$b){
$Y.style.visibility='visible';
if(!$b)$b='block';
$Y.style.display=$b;
}
function _getel(id){
return document.getElementById(id);
}
function _getval(id){
var ob=document.getElementById(id);
if(!ob)return;
if(ob.type=='checkbox'){
return ob.checked;
}
if(ob.type=='radio'){
var $B=ob.form[ob.name],$R;
for(i=0;i<$B.length;i++)if($B[i].checked)$R=i;
var $d=$B[$R].value;
return $d!='on'? $d:$R;
}
if(ob.nodeName=='SELECT'){
var $R=ob.selectedIndex,$T=ob.options[$R];
return $T.value? $T.value:$T.innerHTML;
}
return ob.value;
}
function _setval(id,val){
var ob=document.getElementById(id);
ob.value=val;
}
function _getselval(id){return _getval(id);}
function _newhref($N){
var $A=_newel('a');
$A.href=$N;
return $A;
}
function _newbr($M){
var $D=document.createElement('br');
if($M){
$D.clear=$M;
}
return $D;
}
function _newnbsp(){
return document.createTextNode('\u00a0');
}
function _newel($X){
return document.createElement($X);
}
function _newtext($K){
return document.createTextNode($K);
}
function _newtable(){
  var $e=_newel('table'),$I=_newel('tbody');
  _append($e,$I);
  var $h={table:$e,tbody:$I},$V=arguments.length;
  if($V){
  for(var i=0;i<$V;i++){
  var tr=_newtr(arguments[i]);
  _append($I,tr.tr);
  $h['tr'+(i+1)]=tr;
  }
  }
  return $h;
}
function _newtr($G){
var tr=_newel('tr'),$g={tr:tr};
for(var i=1;i<=$G;i++){
var td=_newel('td');
$g['td'+i]=td;
_append(tr,td);
}
return $g;
}
function _newdiv($Z){
var $W=document.createElement('div');
$W.className=$Z;
return $W;
}
function _newoption($K,$d){
if(!$d)$d=$K;
var $L=document.createElement('option');
$L.value=$d;
_append($L,_newtext($K));
return $L;
}
function _newimg($F){
var $C=document.createElement('img');
$C.src=$F;
return $C;
}
function _newform($Q,$c,$P){
var $S=document.createElement('form');
$S.action=$Q;
$S.method='post';
if($c)$S.enctype='multipart/form-data';
if($P){
for(var i in $P){
var $U=_newhidden(i,$P[i]);
_append($S,$U);
}
}
return $S;
}
function _newicon($F,id,$Z){
var $C=_newimg($F);
$C.style.border=0;
$C.style.cursor='pointer';
$C.isicon=1;
$C.iconsrc=$F;
if(id)$C.id=id;
if($Z)$C.className=$Z;
return $C;
}
function _newhidden($X,$O){return _newi('hidden',$O,$X);}
function _newi($b,$O,$X){
var $H=document.createElement('input');
$H.type=$b;
if($X){
$H.name=$X;
$H.id=$X;
}
if($O)$H.value=$O;
return $H;
}
function _del($Y){
$Y.parentNode.removeChild($Y);
}
function _append(){
var $V=arguments.length;
if($V<2)return;
var $a=arguments[0];
if(!$a)return;
for(var i=1;i<$V;i++){
if($a.appendChild){
$a.appendChild(arguments[i]);
}
}
return $a;
}
function _insertbefore(){
var $V=arguments.length;
if($V<2)return;
var $a=arguments[0];
for(var i=1;i<$V;i++){
$a.parentNode.insertBefore(arguments[i],$a);
}
}
function _insertafter(){
var $V=arguments.length;
if($V<2)return;
var $a=arguments[0];
for(var i=1;i<$V;i++){
$a.parentNode.insertBefore(arguments[i],$a.nextSibling);
}
}
function _replace($J,$f){
$J.parentNode.replaceChild($f,$J);
}
function _clear($Y){
if(!$Y)return;
while($Y.firstChild){
$Y.removeChild($Y.firstChild);
}
}
function _up($Y){
return $Y.parentNode;
}
function _apptext($Y,$K){
_append($Y,_newtext($K));
}
function _getbyclass(find,rootel){
rootel=rootel||document.body;
find=' '+find+' ';
var els=rootel.getElementsByTagName('*'),found=[];
for(var i=0;i<els.length;i++){
var check=' '+els[i].className+' ';
if(check.indexOf(find)!=-1)found.push(els[i]);
}
return found;
}
function _getbyclassprefix(find,rootel){
rootel=rootel||document.body;
find=' '+find;
var els=rootel.getElementsByTagName('*'),found=[];
for(var i=0;i<els.length;i++){
var check=' '+els[i].className+' ';
if(check.indexOf(find)!=-1)found.push(els[i]);
}
return found;
}