self.addEventListener('push',event=>{
  let payload={};
  try { payload=event.data?.json()??{}; } catch { /* Still display a notification for every push. */ }
  event.waitUntil(self.registration.showNotification('다니엘저울',{
    body:payload.body||'담당 학급의 알림을 확인해주세요.',tag:payload.tag||'homeroom',
    icon:'/logo.svg',data:{url:'/teacher'}
  }));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const url=new URL('/teacher',self.location.origin).href;
    for(const client of await self.clients.matchAll({type:'window',includeUncontrolled:true})) {
      if(new URL(client.url).origin===self.location.origin) {await client.navigate(url);return client.focus();}
    }
    return self.clients.openWindow(url);
  })());
});
