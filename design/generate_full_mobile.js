const fs = require('fs');

const C = {
  canvas: '#0B0B0F', surface: '#121217', raised: '#1A1A22', interactive: '#24242E',
  line: '#2C2C38', text: '#F6F5FA', muted: '#9B99A8', faint: '#6E6B79',
  violet: '#7C5CFF', violet2: '#A88FFF', violetDark: '#4D36B6',
  green: '#42D392', amber: '#F7B84B', red: '#FF5D6C', white: '#FFFFFF', black: '#07070A'
};

const W = 2200, H = 4400, PW = 390, PH = 844;
const out = [];
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const rect = (x,y,w,h,fill,r=0,stroke='',sw=1,op=1) => out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}"${stroke?` stroke="${stroke}" stroke-width="${sw}"`:''}${op!==1?` opacity="${op}"`:''}/>`);
const line = (x1,y1,x2,y2,stroke=C.line,sw=1,dash='') => out.push(`<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${stroke}" stroke-width="${sw}"${dash?` stroke-dasharray="${dash}"`:''}/>`);
const circle = (cx,cy,r,fill,stroke='',sw=1) => out.push(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}"${stroke?` stroke="${stroke}" stroke-width="${sw}"`:''}/>`);
const path = (d,stroke=C.text,sw=2,fill='none') => out.push(`<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"/>`);
const txt = (x,y,s,size=14,fill=C.text,weight=400,anchor='start',opacity=1,spacing=0) => out.push(`<text x="${x}" y="${y}" fill="${fill}" font-family="Manrope, Arial, sans-serif" font-size="${size}" font-weight="${weight}" text-anchor="${anchor}" opacity="${opacity}" letter-spacing="${spacing}">${esc(s)}</text>`);
const multi = (x,y,lines,size=14,fill=C.text,weight=400,lh=20,anchor='start') => { lines.forEach((s,i)=>txt(x,y+i*lh,s,size,fill,weight,anchor)); };
const gradientDefs = () => out.push(`<defs>
  <linearGradient id="accent" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#A88FFF"/><stop offset="1" stop-color="#6B46FF"/></linearGradient>
  <linearGradient id="glow" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7C5CFF" stop-opacity=".42"/><stop offset="1" stop-color="#16121F" stop-opacity="0"/></linearGradient>
  <linearGradient id="camera" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#252130"/><stop offset="1" stop-color="#0C0C11"/></linearGradient>
  <filter id="soft"><feGaussianBlur stdDeviation="34"/></filter>
</defs>`);

function icon(x,y,type,color=C.text,s=20){
  const k=s/24;
  out.push(`<g transform="translate(${x} ${y}) scale(${k})" fill="none" stroke="${color}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">`);
  const map={
    chat:'<path d="M5 5h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H10l-5 4v-4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z"/>',
    people:'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
    user:'<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    search:'<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
    plus:'<path d="M12 5v14M5 12h14"/>',
    back:'<path d="m15 18-6-6 6-6"/>',
    phone:'<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.79 19.79 0 0 1 2.12 4.2 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.9.33 1.78.62 2.63a2 2 0 0 1-.45 2.11L8 9.73a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.85.29 1.73.5 2.63.62A2 2 0 0 1 22 16.92Z"/>',
    send:'<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    lock:'<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    shield:'<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>',
    copy:'<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>',
    qr:'<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><path d="M14 14h3v3h4v4h-7Z"/>',
    settings:'<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06-2.83 2.83-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21h-4v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06-2.83-2.83.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3v-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06L7.04 4.3l.06.06A1.65 1.65 0 0 0 8.92 4a1.65 1.65 0 0 0 1-1.51V2h4v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06 2.83 2.83-.06.06A1.65 1.65 0 0 0 19.4 9c.12.37.2.75.21 1.14H21v4h-1.39c-.01.3-.09.6-.21.86Z"/>',
    wifi:'<path d="M5 12.55a11 11 0 0 1 14 0M8.5 16a6 6 0 0 1 7 0M12 20h.01"/>',
    eye:'<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z"/><circle cx="12" cy="12" r="2.5"/>',
    check:'<path d="m5 12 4 4L19 6"/>',
    more:'<circle cx="5" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="19" cy="12" r="1" fill="currentColor"/>',
    key:'<circle cx="8" cy="15" r="4"/><path d="m11 12 9-9M15 8l3 3M18 5l3 3"/>',
    camera:'<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2Z"/><circle cx="12" cy="13" r="4"/>',
    paste:'<rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4V2h6v2M9 9h6M9 13h6"/>',
    bell:'<path d="M18 8a6 6 0 1 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
    link:'<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>'
  };
  out.push(map[type]||map.more); out.push('</g>');
}

function phoneBase(x,y,label,step){
  txt(x,y-20,`${step} · ${label.toUpperCase()}`,12,C.violet2,700,'start',1,1.1);
  rect(x,y,PW,PH,C.black,42,C.line,2);
  rect(x+8,y+8,PW-16,PH-16,C.surface,35);
  txt(x+30,y+34,'9:41',11,C.text,700);
  rect(x+153,y+15,84,23,C.black,12);
  path(`M${x+318} ${y+27}h12`,C.text,1.5); path(`M${x+322} ${y+23}l4 4 4-4`,C.text,1.5);
  rect(x+344,y+21,20,10,'none',3,C.text,1); rect(x+346,y+23,15,6,C.text,2); rect(x+365,y+24,2,4,C.text,1);
  return {x:x+20,y:y+54,w:PW-40,h:PH-74};
}
function header(p,title,opts={}){
  if(opts.back) icon(p.x,p.y+4,'back',C.text,22);
  txt(p.x+(opts.back?34:0),p.y+22,title,24,C.text,800);
  if(opts.sub) txt(p.x+(opts.back?34:0),p.y+42,opts.sub,10,C.muted,500);
  if(opts.action){ circle(p.x+p.w-18,p.y+18,18,C.interactive); icon(p.x+p.w-28,p.y+8,opts.action,C.text,20); }
}
function pill(x,y,w,label,fill=C.interactive,color=C.text,ic=''){
  rect(x,y,w,32,fill,16); if(ic) icon(x+10,y+7,ic,color,17); txt(x+(ic?34:14),y+21,label,11,color,700);
}
function button(x,y,w,label,kind='primary',ic=''){
  const fill=kind==='primary'?'url(#accent)':kind==='secondary'?C.interactive:'none';
  const stroke=kind==='ghost'?C.line:''; rect(x,y,w,48,fill,15,stroke,1);
  if(ic) icon(x+18,y+14,ic,kind==='primary'?C.white:C.text,19);
  txt(x+w/2+(ic?8:0),y+30,label,13,kind==='primary'?C.white:C.text,750,'middle');
}
function avatar(cx,cy,r,initial,color=C.violet,online=false){
  circle(cx,cy,r,color); txt(cx,cy+5,initial,Math.max(10,r*.62),C.white,750,'middle');
  if(online){circle(cx+r*.72,cy+r*.72,5,C.surface);circle(cx+r*.72,cy+r*.72,3,C.green);}
}
function searchBar(x,y,w,active=false,label='Поиск по чатам'){
  rect(x,y,w,42,active?C.interactive:'#17171E',13,active?C.violetDark:C.line,active?1.3:1);
  icon(x+13,y+11,'search',active?C.violet2:C.muted,19); txt(x+42,y+26,label,12,active?C.text:C.muted,500);
}
function nav(x,y,w,sel=0){
  rect(x,y,w,64,C.raised,21,C.line,1);
  const data=[['chat','Чаты'],['people','Контакты'],['user','Профиль']];
  data.forEach((d,i)=>{ const cx=x+52+i*(w-104)/2; if(i===sel) rect(cx-36,y+8,72,34,C.violetDark,17); icon(cx-10,y+14,d[0],i===sel?C.white:C.muted,20); txt(cx,y+54,d[1],9,i===sel?C.text:C.muted,i===sel?700:500,'middle'); });
}
function chatRow(x,y,w,name,preview,time,initial,color,unread=0,state='online'){
  avatar(x+24,y+29,22,initial,color,state==='online'); txt(x+58,y+22,name,13,C.text,700); txt(x+58,y+42,preview,11,C.muted,500);
  txt(x+w-8,y+18,time,9,C.faint,500,'end');
  if(unread){circle(x+w-14,y+39,10,C.violet);txt(x+w-14,y+43,String(unread),9,C.white,800,'middle');}
  else if(state==='queued'){circle(x+w-15,y+39,4,C.amber);}
  else { path(`M${x+w-28} ${y+38}l4 4 7-8M${x+w-22} ${y+38}l4 4 7-8`,C.violet2,1.3); }
  line(x+58,y+57,x+w,y+57,C.line,.7);
}
function bubble(x,y,w,lines,outgoing=false,status=''){
  const h=lines.length*17+24; rect(x,y,w,h,outgoing?'url(#accent)':C.interactive,16); multi(x+14,y+22,lines,11,outgoing?C.white:C.text,500,17);
  if(status){txt(x+w-12,y+h-8,status,8,outgoing?'#E4DDFF':C.muted,500,'end');}
  return h;
}
function menuRow(x,y,w,ic,title,sub='',right='›',color=C.text){
  icon(x+14,y+14,ic,C.violet2,20); txt(x+50,y+24,title,13,color,650); if(sub) txt(x+50,y+42,sub,10,C.muted,500); txt(x+w-14,y+29,right,18,C.faint,500,'end'); line(x+50,y+55,x+w,y+55,C.line,.7);
}
function qr(x,y,size){
  rect(x,y,size,size,C.white,18);
  const m=7, u=(size-28)/m, ox=x+14, oy=y+14;
  const cells=['1110111','1010101','1110111','0001000','1110111','1011101','1110101'];
  cells.forEach((row,yy)=>[...row].forEach((v,xx)=>{if(v==='1')rect(ox+xx*u,oy+yy*u,u-2,u-2,C.black,2);}));
  circle(x+size/2,y+size/2,24,C.violet); txt(x+size/2,y+size/2+6,'N',17,C.white,800,'middle');
}

function screenWelcome(x,y){ const p=phoneBase(x,y,'Добро пожаловать','01');
  circle(x+PW/2,y+185,76,'url(#glow)'); rect(x+161,y+108,68,68,'url(#accent)',20); icon(x+183,y+130,'chat',C.white,25);
  txt(x+PW/2,y+224,'Связь без анкеты',27,C.text,800,'middle'); txt(x+PW/2,y+253,'и центральной точки',27,C.text,800,'middle');
  multi(x+PW/2,y+292,['Ключи создаются на устройстве.','Телефон и почта не нужны.'],12,C.muted,500,20,'middle');
  [['shield','Сквозное шифрование'],['wifi','LAN, relay и offline outbox'],['user','Анонимная локальная личность']].forEach((r,i)=>{rect(x+30,y+347+i*62,330,50,C.raised,15,C.line,1);icon(x+44,y+361+i*62,r[0],C.violet2,19);txt(x+78,y+378+i*62,r[1],12,C.text,650);});
  button(x+30,y+578,330,'Создать личность','primary','key'); button(x+30,y+638,330,'Восстановить по коду','secondary','copy');
  txt(x+PW/2,y+720,'Продолжая, вы создаёте ключи только локально',9,C.faint,500,'middle');
}
function screenIdentity(x,y){const p=phoneBase(x,y,'Создание личности','02');header(p,'Новая личность',{back:true,sub:'Шаг 1 из 3'});
  pill(p.x,p.y+64,104,'1  Личность',C.violetDark,C.white); pill(p.x+112,p.y+64,94,'2  Backup'); pill(p.x+214,p.y+64,112,'3  Готово');
  rect(p.x,p.y+120,p.w,172,C.raised,22,C.line,1); circle(x+PW/2,p.y+176,44,'url(#accent)');txt(x+PW/2,p.y+184,'N',29,C.white,800,'middle');
  txt(p.x+18,p.y+244,'Псевдоним',11,C.muted,600);rect(p.x+18,p.y+254,p.w-36,44,C.interactive,13,C.violetDark,1);txt(p.x+34,p.y+281,'Nikita',13,C.text,650);
  txt(p.x,p.y+332,'Что будет создано',15,C.text,750);
  [['key','X25519 ключевая пара'],['shield','Локальное защищённое хранилище'],['link','Публичный invite-код']].forEach((r,i)=>menuRow(p.x,p.y+350+i*58,p.w,r[0],r[1],'','✓'));
  rect(p.x,p.y+550,p.w,62,'#17151F',16,C.violetDark,1); icon(p.x+14,p.y+568,'lock',C.violet2,20);multi(p.x+48,p.y+570,['Секретный ключ не отправляется','на relay-сервер.'],10,C.muted,600,15);
  button(p.x,p.y+646,p.w,'Продолжить','primary');
}
function screenRecovery(x,y){const p=phoneBase(x,y,'Код восстановления','03');header(p,'Сохраните код',{back:true,sub:'Шаг 2 из 3'});
  rect(p.x,p.y+68,p.w,76,'#1D1827',18,C.violetDark,1);icon(p.x+16,p.y+84,'key',C.violet2,22);multi(p.x+52,p.y+90,['Это единственный способ вернуть','личность после потери устройства.'],11,C.text,600,17);
  txt(p.x,p.y+180,'Recovery phrase',11,C.muted,700, 'start',1,1);
  const words=['ember','north','velvet','orbit','canyon','signal','brave','atlas','lumen','forest','echo','violet'];
  words.forEach((w,i)=>{const col=i%2,row=Math.floor(i/2); const bx=p.x+col*169,by=p.y+198+row*48;rect(bx,by,160,38,C.interactive,11);txt(bx+12,by+24,`${i+1}`,9,C.faint,700);txt(bx+38,by+24,w,12,C.text,650);});
  button(p.x,p.y+502,p.w,'Копировать код','secondary','copy');
  rect(p.x,p.y+566,22,22,C.violet,7);icon(p.x+2,p.y+568,'check',C.white,18);multi(p.x+34,p.y+579,['Я сохранил код в безопасном месте','и никому его не отправлю'],11,C.text,600,17);
  button(p.x,p.y+654,p.w,'Открыть мессенджер','primary');
}
function screenChats(x,y){const p=phoneBase(x,y,'Чаты · populated','04');header(p,'Чаты',{sub:'Защищённая связь',action:'plus'});searchBar(p.x,p.y+58,p.w);
  txt(p.x,p.y+128,'В СЕТИ',9,C.muted,700,'start',1,1);[['М','Маша',C.violet],['А','Антон','#3E9BCB'],['Л','Лена','#F28A62'],['+','Добавить',C.interactive]].forEach((a,i)=>{avatar(p.x+25+i*72,p.y+164,22,a[0],a[2],i<3);txt(p.x+25+i*72,p.y+198,a[1],8,C.muted,600,'middle');});
  txt(p.x,p.y+232,'СООБЩЕНИЯ',9,C.muted,700,'start',1,1);
  chatRow(p.x,p.y+246,p.w,'Маша К.','Отправила фото · только что','14:32','МК',C.violet,2);
  chatRow(p.x,p.y+306,p.w,'Антон К.','Увидимся вечером?','14:02','АК','#3E9BCB',0,'online');
  chatRow(p.x,p.y+366,p.w,'Лена','Сообщение ждёт сети','13:11','Л','#F28A62',0,'queued');
  chatRow(p.x,p.y+426,p.w,'Тестовая группа','5 участников · relay','вчера','Т','#4B4858',0,'online');
  rect(p.x,p.y+505,p.w,48,'#151820',14,C.line,1);circle(p.x+18,p.y+529,4,C.green);txt(p.x+32,p.y+525,'LAN доступен',10,C.text,650);txt(p.x+32,p.y+540,'relay — резервный маршрут',8,C.muted,500);icon(p.x+p.w-28,p.y+517,'plus',C.muted,20);
  nav(p.x,p.y+678,p.w,0);
}
function screenSearch(x,y){const p=phoneBase(x,y,'Поиск','05');header(p,'Чаты',{action:'plus'});searchBar(p.x,p.y+58,p.w,true,'маша');
  txt(p.x,p.y+124,'3 РЕЗУЛЬТАТА',9,C.muted,700,'start',1,1);chatRow(p.x,p.y+140,p.w,'Маша К.','Совпадение в имени','контакт','МК',C.violet,0,'online');
  txt(p.x,p.y+224,'СООБЩЕНИЯ',9,C.muted,700,'start',1,1);chatRow(p.x,p.y+240,p.w,'Маша К.','«Маша пришлёт ключ позже»','12 авг','МК',C.violet,0,'online');chatRow(p.x,p.y+300,p.w,'Тестовая группа','«Добавьте Машу в группу»','8 авг','Т','#4B4858',0,'online');
  rect(p.x,p.y+392,p.w,116,C.raised,18,C.line,1);icon(p.x+16,p.y+408,'lock',C.violet2,20);txt(p.x+50,p.y+424,'Локальный поиск',13,C.text,700);multi(p.x+16,p.y+454,['Запрос не отправляется на сервер.','Ищем только в вашей базе контактов'],10,C.muted,500,16);
  nav(p.x,p.y+678,p.w,0);
}
function screenConversation(x,y,offline=false){const p=phoneBase(x,y,offline?'Диалог · offline':'Диалог · online',offline?'07':'06');
  icon(p.x,p.y+7,'back',C.text,21);avatar(p.x+50,p.y+19,18,'МК',C.violet,!offline);txt(p.x+78,p.y+15,'Маша К.',13,C.text,750);txt(p.x+78,p.y+32,offline?'нет сети · очередь':'в сети · LAN',9,offline?C.amber:C.green,600);icon(p.x+p.w-25,p.y+7,'phone',C.text,20);
  if(offline){rect(p.x,p.y+52,p.w,42,'#2B2419',13,C.amber,1);circle(p.x+16,p.y+73,4,C.amber);txt(p.x+30,p.y+77,'Нет маршрута — сообщения сохраняются',10,C.amber,650);}
  pill(p.x+96,p.y+(offline?108:58),158,'Зашифровано',' #211B32'.trim(),C.violet2,'lock');
  const base=p.y+(offline?158:110); txt(x+PW/2,base,'Сегодня',9,C.faint,600,'middle');
  let yy=base+18; yy+=bubble(p.x,yy,210,['Привет! Ты уже проверил','новую сборку?'],false,'14:29')+10;
  yy+=bubble(p.x+84,yy,246,['Да. LAN обнаружился сразу,','заметно быстрее ✨'],true,offline?'в очереди':'14:30 ✓✓')+10;
  if(!offline){rect(p.x,yy,266,76,C.interactive,16);path(`M${p.x+18} ${yy+44}l15-15 12 19 13-28 14 33 14-17 17 14 18-8`,C.violet2,1.5);circle(p.x+235,yy+38,14,C.amber);txt(p.x+258,yy+63,'0:12',8,C.muted,600,'end');yy+=88;yy+=bubble(p.x+118,yy,212,['Смотрю, спасибо'],true,'14:31 ✓✓')+10;}
  else { yy+=bubble(p.x+48,yy,282,['Фото и текст будут отправлены,','когда появится LAN или relay.'],true,'в очереди')+10;rect(p.x,yy,p.w,54,'#17151F',15,C.violetDark,1);icon(p.x+14,yy+16,'wifi',C.violet2,20);txt(p.x+48,yy+22,'Очередь: 2 сообщения',11,C.text,700);txt(p.x+48,yy+39,'Повтор через 18 сек.',9,C.muted,500);}
  const cy=p.y+677;rect(p.x,cy,p.w,58,C.raised,20,C.line,1);circle(p.x+25,cy+29,17,C.interactive);icon(p.x+15,cy+19,'plus',C.muted,20);txt(p.x+55,cy+34,offline?'Сообщение сохранится локально':'Сообщение',10,C.muted,500);circle(p.x+p.w-28,cy+29,20,'url(#accent)');icon(p.x+p.w-38,cy+19,'send',C.white,20);
}
function screenContacts(x,y){const p=phoneBase(x,y,'Контакты','08');header(p,'Контакты',{sub:'4 контакта',action:'plus'});searchBar(p.x,p.y+58,p.w,false,'Имя или fingerprint');
  txt(p.x,p.y+126,'РЯДОМ',9,C.muted,700,'start',1,1);chatRow(p.x,p.y+142,p.w,'Антон К.','LAN · проверен сегодня','рядом','АК','#3E9BCB',0,'online');chatRow(p.x,p.y+202,p.w,'Маша К.','LAN · fingerprint совпадает','рядом','МК',C.violet,0,'online');
  txt(p.x,p.y+286,'ОСТАЛЬНЫЕ',9,C.muted,700,'start',1,1);chatRow(p.x,p.y+302,p.w,'Лена','Последний relay: 13:11','13:11','Л','#F28A62',0,'queued');chatRow(p.x,p.y+362,p.w,'Саша','Только invite-код','3 дня','С','#568A69',0,'queued');
  button(p.x,p.y+470,p.w,'Добавить контакт','primary','plus');nav(p.x,p.y+678,p.w,1);
}
function screenScanner(x,y){const p=phoneBase(x,y,'Добавить контакт','09');header(p,'Добавить контакт',{back:true});
  rect(p.x,p.y+54,p.w,44,C.interactive,14);rect(p.x+4,p.y+58,(p.w-8)/2,36,C.violetDark,11);icon(p.x+22,p.y+66,'camera',C.white,18);txt(p.x+52,p.y+80,'Камера',11,C.white,700);icon(p.x+190,p.y+66,'paste',C.muted,18);txt(p.x+220,p.y+80,'Ввести код',11,C.muted,650);
  rect(p.x,p.y+116,p.w,430,'url(#camera)',24,C.line,1);circle(p.x+70,p.y+174,90,'#2C243B');circle(p.x+286,p.y+446,120,'#172328');
  const sx=p.x+64,sy=p.y+190,sz=222;path(`M${sx+42} ${sy}H${sx}v42 M${sx+180} ${sy}h42v42 M${sx} ${sy+180}v42h42 M${sx+222} ${sy+180}v42h-42`,C.violet2,4);
  qr(p.x+105,p.y+232,140);circle(p.x+120,p.y+500,20,C.interactive);icon(p.x+110,p.y+490,'eye',C.text,20);circle(p.x+230,p.y+500,20,C.interactive);icon(p.x+220,p.y+490,'camera',C.text,20);
  multi(x+PW/2,p.y+582,['Наведите камеру на QR-код','другого пользователя'],11,C.muted,500,17,'middle');pill(p.x+84,p.y+635,182,'Код не содержит backup',C.raised,C.violet2,'shield');
}
function screenInvite(x,y){const p=phoneBase(x,y,'Моё приглашение','10');header(p,'Приглашение',{back:true,sub:'Публичный ключ'});avatar(x+PW/2,p.y+98,42,'N','url(#accent)',true);txt(x+PW/2,p.y+158,'Nikita',17,C.text,800,'middle');txt(x+PW/2,p.y+178,'Локальная личность',10,C.muted,500,'middle');qr(p.x+52,p.y+210,246);button(p.x,p.y+478,p.w,'Поделиться приглашением','primary','link');
  rect(p.x,p.y+540,p.w,54,C.raised,15,C.line,1);icon(p.x+14,p.y+557,'link',C.violet2,18);txt(p.x+46,p.y+562,'p2p1.invite.7f3a…9fc2',10,C.text,600);icon(p.x+p.w-34,p.y+556,'copy',C.muted,18);
  multi(x+PW/2,p.y+634,['Invite содержит публичный ключ.','Recovery-кода здесь нет.'],10,C.muted,500,16,'middle');
}
function screenProfile(x,y){const p=phoneBase(x,y,'Профиль','11');header(p,'Профиль',{action:'settings'});avatar(x+PW/2,p.y+106,48,'N','url(#accent)',true);txt(x+PW/2,p.y+172,'Nikita',20,C.text,800,'middle');txt(x+PW/2,p.y+193,'Локальная личность',10,C.muted,500,'middle');
  rect(p.x,p.y+222,p.w,82,'#1B1726',18,C.violetDark,1);icon(p.x+16,p.y+242,'shield',C.violet2,24);txt(p.x+56,p.y+248,'Ключи на устройстве',13,C.text,750);txt(p.x+56,p.y+269,'Secure storage · backup подтверждён',9,C.muted,500);pill(p.x+256,p.y+242,78,'Защищено',C.violetDark,C.violet2);
  menuRow(p.x,p.y+328,p.w,'qr','Моё приглашение','QR и текстовый код');menuRow(p.x,p.y+386,p.w,'key','Код восстановления','Показывать только приватно');menuRow(p.x,p.y+444,p.w,'shield','Безопасность','Криптосхема и fingerprint');menuRow(p.x,p.y+502,p.w,'wifi','Сеть и маршруты','LAN → relay → outbox');
  nav(p.x,p.y+678,p.w,2);
}
function screenSecurity(x,y){const p=phoneBase(x,y,'Безопасность','12');header(p,'Защита диалога',{back:true});circle(x+PW/2,p.y+128,66,'#1D1830');icon(x+PW/2-28,p.y+100,'shield',C.violet2,56);txt(x+PW/2,p.y+218,'Соединение защищено',18,C.text,800,'middle');txt(x+PW/2,p.y+240,'X25519 + AES-GCM',11,C.violet2,650,'middle');
  rect(p.x,p.y+278,p.w,106,C.raised,18,C.line,1);txt(p.x+16,p.y+303,'ОТПЕЧАТОК КОНТАКТА',9,C.muted,700,'start',1,1);multi(p.x+16,p.y+335,['A9 3C 7F 12 · 6B E4 90 22','D1 08 AA 5E · 7C F2 19 8D'],13,C.text,700,24);icon(p.x+p.w-36,p.y+304,'copy',C.muted,18);
  rect(p.x,p.y+406,p.w,116,'#17151F',18,C.violetDark,1);txt(p.x+16,p.y+431,'Как проверить',13,C.text,750);multi(p.x+16,p.y+456,['Сравните fingerprint лично или','по другому доверенному каналу.'],10,C.muted,500,17);pill(p.x+16,p.y+486,114,'Не проверен','#2D2418',C.amber);
  button(p.x,p.y+566,p.w,'Отметить как проверенный','primary','check');txt(x+PW/2,p.y+646,'Double Ratchet — следующий этап протокола',9,C.faint,500,'middle');
}
function screenSettings(x,y){const p=phoneBase(x,y,'Настройки сети','13');header(p,'Сеть и маршруты',{back:true});
  rect(p.x,p.y+58,p.w,120,C.raised,20,C.line,1);circle(p.x+38,p.y+96,20,'#173127');circle(p.x+38,p.y+96,6,C.green);txt(p.x+72,p.y+91,'Связь доступна',14,C.text,750);txt(p.x+72,p.y+111,'LAN активен · relay готов',10,C.muted,500);pill(p.x+16,p.y+132,91,'Онлайн','#173127',C.green,'wifi');pill(p.x+115,p.y+132,98,'Relay 42ms',C.interactive,C.text);pill(p.x+221,p.y+132,105,'Очередь 0',C.interactive,C.text);
  txt(p.x,p.y+214,'ПОРЯДОК ДОСТАВКИ',9,C.muted,700,'start',1,1);[['1','Локальная сеть','Самый быстрый маршрут'],['2','Relay','Только зашифрованные пакеты'],['3','Outbox','Хранить до появления сети']].forEach((r,i)=>{const yy=p.y+230+i*70;circle(p.x+20,yy+22,16,i===0?C.violetDark:C.interactive);txt(p.x+20,yy+27,r[0],11,C.text,800,'middle');txt(p.x+52,yy+18,r[1],12,C.text,700);txt(p.x+52,yy+38,r[2],9,C.muted,500);txt(p.x+p.w-8,yy+28,'⋮⋮',14,C.faint,600,'end');line(p.x+52,yy+55,p.x+p.w,yy+55,C.line,.7);});
  txt(p.x,p.y+462,'ПАРАМЕТРЫ',9,C.muted,700,'start',1,1);menuRow(p.x,p.y+478,p.w,'wifi','Поиск рядом','mDNS / Bonjour','ON');menuRow(p.x,p.y+536,p.w,'bell','Фоновые уведомления','Новые зашифрованные пакеты','ON');menuRow(p.x,p.y+594,p.w,'lock','Только HTTPS relay','Рекомендуется для release','ON');
}
function screenEmpty(x,y){const p=phoneBase(x,y,'Чаты · empty state','14');header(p,'Чаты',{sub:'Защищённая связь',action:'plus'});searchBar(p.x,p.y+58,p.w);
  circle(x+PW/2,p.y+256,82,'#1B1728');circle(x+PW/2,p.y+256,48,'url(#accent)');icon(x+PW/2-24,p.y+232,'chat',C.white,48);txt(x+PW/2,p.y+374,'Здесь пока тихо',21,C.text,800,'middle');multi(x+PW/2,p.y+402,['Добавьте контакт по QR-коду','или поделитесь приглашением.'],11,C.muted,500,18,'middle');button(p.x,p.y+468,p.w,'Добавить первый контакт','primary','plus');button(p.x,p.y+528,p.w,'Показать мой QR','secondary','qr');nav(p.x,p.y+678,p.w,0);
}

function componentsBoard(){
  rect(70,150,W-140,360,C.surface,28,C.line,1);txt(100,190,'MOBILE SYSTEM · V1',11,C.violet2,800,'start',1,1.4);txt(100,230,'Компоненты, состояния и motion',24,C.text,800);txt(100,257,'8pt grid · tap target ≥ 44 · контраст AA · dark-first',11,C.muted,500);
  txt(100,304,'BUTTONS',9,C.faint,700,'start',1,1);button(100,320,190,'Продолжить','primary');button(300,320,170,'Вторичное','secondary');button(480,320,130,'Ghost','ghost');
  txt(660,304,'STATUS',9,C.faint,700,'start',1,1);pill(660,320,96,'Онлайн','#173127',C.green,'wifi');pill(766,320,104,'В очереди','#2D2418',C.amber);pill(880,320,104,'Encrypted','#211B32',C.violet2,'lock');
  txt(1030,304,'MESSAGE',9,C.faint,700,'start',1,1);bubble(1030,320,190,['Привет! На связи?'],false,'14:29');bubble(1230,320,210,['Да, через LAN ✓'],true,'14:30 ✓✓');
  txt(1490,304,'MOTION',9,C.faint,700,'start',1,1);[['Panel','280ms · 0.16,1,0.3,1'],['Message','260ms · y8 → 0'],['Stagger','40ms · max 5'],['Reduced','opacity only']].forEach((r,i)=>{rect(1490+i*135,320,125,62,C.raised,13,C.line,1);txt(1502+i*135,344,r[0],10,C.text,700);txt(1502+i*135,363,r[1],7.5,C.muted,500);});
  line(100,408,W-100,408,C.line,1);txt(100,444,'COLOR',9,C.faint,700,'start',1,1);[[C.canvas,'Canvas'],[C.surface,'Surface'],[C.raised,'Raised'],[C.violet,'Accent'],[C.green,'Success'],[C.amber,'Queued'],[C.red,'Error']].forEach((r,i)=>{circle(130+i*95,472,14,r[0],C.line,1);txt(152+i*95,476,r[1],9,C.muted,600);});
}

out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`); gradientDefs();
rect(0,0,W,H,C.canvas,36); circle(1990,120,250,C.violet, '',1); out.push('<circle cx="1990" cy="120" r="250" fill="#7C5CFF" opacity=".18" filter="url(#soft)"/>');
txt(70,68,'MASSJJ · MOBILE PRODUCT DESIGN',11,C.violet2,800,'start',1,1.5);txt(70,112,'Полный мобильный flow',34,C.text,800);txt(2120,92,'14 экранов · RU · 390 × 844',12,C.muted,600,'end');
componentsBoard();

const xs=[70,600,1130,1660], ys=[570,1500,2430,3360];
screenWelcome(xs[0],ys[0]);screenIdentity(xs[1],ys[0]);screenRecovery(xs[2],ys[0]);screenChats(xs[3],ys[0]);
screenSearch(xs[0],ys[1]);screenConversation(xs[1],ys[1],false);screenConversation(xs[2],ys[1],true);screenContacts(xs[3],ys[1]);
screenScanner(xs[0],ys[2]);screenInvite(xs[1],ys[2]);screenProfile(xs[2],ys[2]);screenSecurity(xs[3],ys[2]);
screenSettings(xs[0],ys[3]);screenEmpty(xs[1],ys[3]);

// Flow connectors and row captions
[['ONBOARDING → CORE',ys[0]-52],['SEARCH → CONVERSATION → CONTACTS',ys[1]-52],['CONTACT EXCHANGE → TRUST',ys[2]-52],['SYSTEM STATES',ys[3]-52]].forEach(r=>{txt(70,r[1],r[0],10,C.faint,800,'start',1,1.2);line(300,r[1]-4,2120,r[1]-4,C.line,1,'6 8');});
txt(1660,3550,'NAVIGATION MAP',9,C.faint,700,'start',1,1);rect(1660,3570,390,280,C.surface,22,C.line,1);
const nodes=[['Onboarding',1730,3630],['Chats',1900,3630],['Dialog',1900,3725],['Contacts',1730,3725],['Profile',1815,3810],['Security',1985,3810]];nodes.forEach((n,i)=>{rect(n[1]-55,n[2]-20,110,40,i===1?C.violetDark:C.raised,12,C.line,1);txt(n[1],n[2]+4,n[0],10,C.text,700,'middle');});
path('M1785 3630H1845M1900 3650V3705M1845 3725H1785M1785 3745l30 45M1845 3790l30-45M1870 3810h60',C.violet2,1.5);
txt(1855,3900,'Smart Animate · 220–320ms · без bounce',10,C.muted,600,'middle');
txt(70,4318,'DELIVERY NOTE',9,C.violet2,800,'start',1,1);txt(70,4342,'Основной маршрут: LAN → relay → encrypted outbox. Recovery-код никогда не попадает в invite.',11,C.muted,500);
txt(2120,4342,'MassJJ / Mobile v1 / 2026',10,C.faint,600,'end');
out.push('</svg>');

fs.writeFileSync(require('path').join(__dirname,'full-mobile-app.svg'), out.join(''), 'utf8');
console.log(`wrote ${out.length} nodes`);
