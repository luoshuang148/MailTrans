#import "MIMECore.h"
#import <stdio.h>

static int failures = 0;
#define CHECK(condition, label) do { if (!(condition)) { fprintf(stderr,"FAIL: %s\n",label); failures++; } } while(0)
static NSData *Bytes(NSString *s) { return [s dataUsingEncoding:NSUTF8StringEncoding]; }
static NSString *DisplayBody(NSData *d) {
 NSString *all=[[NSString alloc]initWithData:d encoding:NSISOLatin1StringEncoding];
 NSRange r=[all rangeOfString:@"\r\n\r\n"];if(r.location==NSNotFound)return @"";
 NSData *body=[[NSData alloc]initWithBase64EncodedString:[all substringFromIndex:NSMaxRange(r)] options:NSDataBase64DecodingIgnoreUnknownCharacters];
 return [[NSString alloc]initWithData:body encoding:NSUTF8StringEncoding]?:@"";
}
static NSString *FirstControlHTML(NSData *data){
 NSString *raw=[[NSString alloc]initWithData:data encoding:NSISOLatin1StringEncoding];
 NSRange start=[raw rangeOfString:@"Content-Transfer-Encoding: base64\r\n\r\n"];
 if(start.location==NSNotFound)return @"";
 NSString *tail=[raw substringFromIndex:NSMaxRange(start)];NSRange end=[tail rangeOfString:@"\r\n--"];
 if(end.location==NSNotFound)return @"";
 NSData *decoded=[[NSData alloc]initWithBase64EncodedString:[tail substringToIndex:end.location]options:NSDataBase64DecodingIgnoreUnknownCharacters];
 return [[NSString alloc]initWithData:decoded encoding:NSUTF8StringEncoding]?:@"";
}
static MTMessage *Message(NSString *type, NSString *body) {
    return [MTMessage messageWithData:Bytes([NSString stringWithFormat:@"Subject: Testing\r\nMessage-ID: <test@example.invalid>\r\nContent-Type: %@\r\n\r\n%@",type,body])];
}
int main(void) {
 @autoreleasepool {
    MTMessage *plain=Message(@"text/plain; charset=utf-8", @"The train will arrive tomorrow.");
    CHECK(plain.eligible && plain.texts.count==1,"plain body extracted");
    CHECK([[plain renderTranslations:nil includeControls:NO] isEqual:plain.original],"original restored byte for byte");
    CHECK([plain renderTranslations:@[] includeControls:NO]==nil,"incomplete result rejected");
    MTMessage *html=Message(@"text/html; charset=utf-8",@"<html><head><style>p{color:red}</style></head><body style='margin:7px'><p style='color:red'>Hello &amp; welcome</p><a href='https://example.com/private?a=1&amp;b=2'>Read details</a><img src='cid:image'><script>secretCode()</script></body></html>");
    CHECK(html.texts.count==2 && [html.texts[0] isEqual:@"Hello & welcome"],"visible HTML text only");
    NSData *rendered=[html renderTranslations:@[@"你好与欢迎",@"查看详情"] includeControls:YES];
    CHECK(rendered!=nil,"HTML translation rendered");
    NSString *markup=DisplayBody(rendered);
    CHECK([markup containsString:@"mailtranslationprobe://restore/"] && ![markup containsString:@"mailtranslationprobe://translate/"],"Chinese view offers only restore action");
    CHECK([markup containsString:@"https://example.com/private?a=1&amp;b=2"] && [markup containsString:@"color:red"] && [markup containsString:@"cid:image"],"HTML links styles and CID retained");
    MTMessage *utfSubject=[MTMessage messageWithData:Bytes(@"Subject: 项目进展\r\nContent-Type: text/plain\r\n\r\nHello tomorrow")];
    CHECK([utfSubject.subject isEqual:@"项目进展"],"raw UTF8 subject decoded");
    MTMessage *roundtrip=[MTMessage messageWithData:rendered ?: NSData.data];
    NSString *joined=[roundtrip.texts componentsJoinedByString:@" "];
    CHECK([joined containsString:@"你好与欢迎"] && ![joined containsString:@"secretCode"],"HTML replacement excludes scripts");
    CHECK([html renderTranslations:nil includeControls:NO] && html.texts.count==2,"render does not mutate source");
    NSData *originalWithControls=[html renderTranslations:nil includeControls:YES];
    CHECK([originalWithControls rangeOfData:html.original options:0 range:NSMakeRange(0,originalWithControls.length)].location!=NSNotFound,"original view wraps unchanged complete MIME source");
    CHECK([FirstControlHTML(originalWithControls)containsString:@"margin:7px"],"control MIME part carries original body presentation for Mail multipart rendering");
    NSString *originalBar=FirstControlHTML(originalWithControls);
    CHECK([originalBar containsString:@"mailtranslationprobe://translate/"] && ![originalBar containsString:@"mailtranslationprobe://restore/"],"original view offers only Chinese action");
    MTMessage *originalWrapped=[MTMessage messageWithData:originalWithControls];
    CHECK([originalWrapped.texts isEqual:html.texts],"separate control part adds no translated or altered source text");

    MTMessage *qp=[MTMessage messageWithData:Bytes(@"Subject: QP\nContent-Type: text/plain; charset=iso-8859-1\nContent-Transfer-Encoding: quoted-printable\n\nCaf=E9 tomorrow")];
    CHECK(qp.eligible && [qp.texts.firstObject containsString:@"Café"],"QP charset decoded");
    NSData *qpWithControls=[qp renderTranslations:nil includeControls:YES];
    CHECK([qpWithControls rangeOfData:qp.original options:0 range:NSMakeRange(0,qpWithControls.length)].location!=NSNotFound,"original control wrapper preserves LF and original charset bytes");
    MTMessage *base=[MTMessage messageWithData:Bytes(@"Content-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\nSGVsbG8gdG9tb3Jyb3c=")];
    CHECK([base.texts.firstObject isEqual:@"Hello tomorrow"],"base64 decoded");
    NSString *nested=@"Content-Type: multipart/mixed; boundary=outer\r\n\r\n--outer\r\nContent-Type: multipart/alternative; boundary=inner\r\n\r\n--inner\r\nContent-Type: text/plain\r\n\r\nFallback text\r\n--inner\r\nContent-Type: text/html\r\n\r\n<p>Tomorrow is sunny.</p>\r\n--inner--\r\n--outer\r\nContent-Type: image/png\r\nContent-Transfer-Encoding: base64\r\nContent-ID: <image>\r\n\r\niVBORw0KGgo=\r\n--outer--\r\n";
    MTMessage *multi=[MTMessage messageWithData:Bytes(nested)];
    CHECK(multi.texts.count==1 && [multi.texts[0] isEqual:@"Tomorrow is sunny."],"nested HTML preferred over alternative plain");
    NSString *multiRendered=[[NSString alloc] initWithData:[multi renderTranslations:@[@"明天晴朗。"] includeControls:YES] encoding:NSISOLatin1StringEncoding];
    CHECK([multiRendered containsString:@"Content-ID: <image>\r\n\r\niVBORw0KGgo=\r\n"],"attachment bytes unchanged");
    NSString *attachment=@"Content-Type: multipart/related; boundary=attached\r\nContent-Disposition: attachment; filename=report.mime\r\n\r\n--attached\r\nContent-Type: text/html\r\n\r\n<p>Attachment content must remain unchanged.</p>\r\n--attached--\r\n";
    NSString *attachedBody=[NSString stringWithFormat:@"--outer\r\nContent-Type: text/plain\r\n\r\nMain body tomorrow.\r\n--outer\r\n%@--outer--\r\n",attachment];
    MTMessage *attached=Message(@"multipart/mixed; boundary=outer",attachedBody);
    CHECK(attached.texts.count==1 && [attached.texts.firstObject isEqual:@"Main body tomorrow."],"multipart attachment subtree excluded");
    NSData *attachedRendered=[attached renderTranslations:@[@"明天的正文。"] includeControls:YES];
    NSString *attachedString=[[NSString alloc]initWithData:attachedRendered encoding:NSISOLatin1StringEncoding];
    CHECK([attachedString containsString:attachment],"multipart attachment raw bytes retained");
    MTMessage *mixed=Message(@"multipart/mixed; boundary=m",@"--m\r\nContent-Type: text/plain\r\n\r\nMain plain message.\r\n--m\r\nContent-Type: text/html\r\n\r\n<p>Independent HTML message.</p>\r\n--m--\r\n");
    CHECK(mixed.texts.count==2 && [mixed.texts[0] isEqual:@"Main plain message."] && [mixed.texts[1] isEqual:@"Independent HTML message."],"independent plain and HTML bodies both selected");
    CHECK(([mixed renderTranslations:@[@"纯文本正文。",@"独立的HTML正文。"] includeControls:YES]!=nil),"independent mixed translations render");
    MTMessage *related=Message(@"multipart/related; boundary=r; start=\"<body>\"",@"--r\r\nContent-Type: text/html\r\nContent-ID: <resource>\r\n\r\n<p>HTML resource must not translate.</p>\r\n--r\r\nContent-Type: text/html\r\nContent-ID: <body>\r\n\r\n<p>Selected root content.</p>\r\n--r--\r\n");
    CHECK(related.texts.count==1 && [related.texts.firstObject isEqual:@"Selected root content."],"related selects declared root and preserves resources");
    CHECK(!Message(@"multipart/signed; boundary=x", @"--x\r\nContent-Type: text/plain\r\n\r\nsecret\r\n--x--").eligible,"signed mail bypassed");
    CHECK(!Message(@"application/pkcs7-mime", @"secret").eligible,"encrypted mail bypassed");
    CHECK(!Message(@"text/plain", @"-----BEGIN PGP MESSAGE-----\nsecret").eligible,"inline PGP bypassed");
    MTMessage *hidden=Message(@"text/html",@"<body><div style='display:none'>Hidden</div><p>Visible</p><pre>code()</pre></body>");
    CHECK(hidden.texts.count==1 && [hidden.texts[0] isEqual:@"Visible"],"hidden and code text excluded");
    NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    MTCache *cache=[[MTCache alloc] initWithRoot:root];
    CHECK([cache rememberMessage:plain],"source cached");
    MTMessage *other=Message(@"text/plain",@"A different message.");
    CHECK([cache rememberMessage:other] && ![plain.key isEqual:other.key],"two messages have distinct identities");
    CHECK([cache setDisplay:Bytes(@"display A") forKey:plain.key],"display committed for exact key");
    CHECK([cache displayForKey:other.key]==nil,"translation isolated from other message");
    [cache restoreKey:plain.key];
    CHECK([[cache storedDisplayForKey:plain.key]isEqual:Bytes(@"display A")],"switching original retains Chinese for immediate switch back");
    CHECK([cache displayForKey:plain.key]==nil && [[cache sourceForKey:plain.key] isEqual:plain.original],"restoration retains original source");
    CHECK(![MTCache isValidKey:@"../../secrets"] && [cache sourceForKey:@"../../secrets"]==nil,"unsafe URL key rejected");
    CHECK([cache sourceForKey:[@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0]]==nil,"missing cache fails closed");
    CHECK([cache setDisplay:Bytes(@"old translation") forKey:plain.key],"display present before expiry");
    NSURL *metaURL=[root URLByAppendingPathComponent:[plain.key stringByAppendingString:@".plist"]];
    NSData *expired=[NSPropertyListSerialization dataWithPropertyList:@{@"subject":@"expired",@"timestamp":@(NSDate.date.timeIntervalSince1970-1801)} format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    [expired writeToURL:metaURL atomically:YES];
    CHECK([cache sourceForKey:plain.key]==nil,"expired source inaccessible");
    [cache rememberMessage:plain];
    CHECK([cache displayForKey:plain.key]==nil,"expired display cannot be revived by opening mail");
    NSURL *sourceURL=[root URLByAppendingPathComponent:[other.key stringByAppendingString:@".source.eml"]];
    [NSFileManager.defaultManager removeItemAtURL:sourceURL error:nil];
    [NSFileManager.defaultManager createSymbolicLinkAtURL:sourceURL withDestinationURL:metaURL error:nil];
    CHECK([cache sourceForKey:other.key]==nil,"symlink source rejected");
    [cache rememberMessage:plain];[cache restoreKey:plain.key];
    NSDictionary *originalChoice=nil;
    for(NSDictionary *entry in cache.recentMessages)if([entry[@"key"]isEqual:plain.key])originalChoice=entry;
    CHECK([originalChoice[@"original"]boolValue],"restore persists explicit original choice");
    [cache rememberMessage:plain];
    MTCache *secondReader=[[MTCache alloc]initWithRoot:root];
    CHECK([secondReader prefersOriginalForKey:plain.key],"Mail refresh cannot undo original choice");
    CHECK(![secondReader prefersOriginalForKey:other.key],"original choice scoped to exact message");
    CHECK([cache setDisplay:Bytes(@"new Chinese display") forKey:plain.key] && ![secondReader prefersOriginalForKey:plain.key],"manual translation returns to Chinese mode");
    MTMessage *fresh=Message(@"text/plain",@"Fresh unchanged message.");
    BOOL changed=NO;
    CHECK([cache rememberMessage:fresh changed:&changed]&&changed,"first cache write reports a change");
    changed=YES;
    CHECK([cache rememberMessage:fresh changed:&changed]&&!changed,"reopening an unchanged message reports no change");
    CHECK([[cache subjectForKey:fresh.key]isEqual:fresh.subject],"subject available without reading source");
    CHECK([cache hasSourceForKey:fresh.key]&&![cache hasTranslatedDisplayForKey:fresh.key],"cheap cache state detects source without translation");
    CHECK([cache setDisplay:Bytes(@"fresh Chinese") forKey:fresh.key]&&[cache hasTranslatedDisplayForKey:fresh.key],"translated state detected by file attributes");
    CHECK([cache activateStoredDisplayForKey:fresh.key]&&[[cache displayForKey:fresh.key]isEqual:Bytes(@"fresh Chinese")],"stored display activates without source hashing");
    [NSFileManager.defaultManager removeItemAtURL:[root URLByAppendingPathComponent:[fresh.key stringByAppendingString:@".source.eml"]] error:nil];
    changed=NO;
    CHECK([cache rememberMessage:fresh changed:&changed]&&changed&&[cache hasSourceForKey:fresh.key],"missing source is rewritten and reported as a change");
    MTMessage *automatic=Message(@"text/plain",@"Automatic translation stays hidden.");
    [cache rememberMessage:automatic];
    CHECK([cache setDisplay:Bytes(@"hidden Chinese") forKey:automatic.key activate:NO],"automatic display can be stored without activation");
    CHECK([cache hasStoredDisplayForKey:automatic.key]&&![cache displayForKey:automatic.key]&&![cache hasTranslatedDisplayForKey:automatic.key],"stored translation is hidden by default");
    CHECK([cache activateStoredDisplayForKey:automatic.key]&&[[cache displayForKey:automatic.key]isEqual:Bytes(@"hidden Chinese")],"only explicit activation shows translation");
    [cache restoreKey:automatic.key];
    CHECK([cache displayForKey:automatic.key]==nil&&[cache prefersOriginalForKey:automatic.key]&&[cache hasStoredDisplayForKey:automatic.key],"restoring original hides translation but keeps it cached");
    MTTranslationQueue *queue=[MTTranslationQueue new];
    [queue enqueueKey:plain.key];[queue enqueueKey:other.key];[queue enqueueKey:plain.key];
    CHECK([[queue takeNextKey]isEqual:plain.key] && [[queue takeNextKey]isEqual:other.key] && [queue takeNextKey]==nil,"automatic requests deduplicate and retain distinct mail order");
    [queue enqueueKey:plain.key];CHECK([queue takeNextKey]==nil,"failed or completed automatic request not repeated on refresh");
    MTTranslationQueue *cancelled=[MTTranslationQueue new];[cancelled enqueueKey:plain.key];[cancelled cancelKey:plain.key];
    CHECK([cancelled takeNextKey]==nil,"restoring a queued message prevents automatic start");
    __block NSTimeInterval now=100;
    MTTranslationQueue *expiring=[[MTTranslationQueue alloc]initWithClock:^{return now;}];
    [expiring enqueueKey:plain.key];[expiring takeNextKey];
    now=1901;[expiring enqueueKey:plain.key];
    CHECK([[expiring takeNextKey]isEqual:plain.key],"opening English after cache lifetime permits new automatic attempt");
    MTTranslationQueue *evicted=[MTTranslationQueue new];[evicted enqueueKey:plain.key];[evicted takeNextKey];[evicted completeKey:plain.key];
    [evicted enqueueKey:plain.key];
    CHECK([[evicted takeNextKey]isEqual:plain.key],"successful mail can auto translate again if its display cache is evicted");
    for(int i=0;i<23;i++) [cache rememberMessage:Message(@"text/plain",[NSString stringWithFormat:@"Message number %d",i])];
    CHECK(cache.recentMessages.count<=20,"cache bounded to twenty");
    [cache clear]; CHECK(cache.recentMessages.count==0,"clear cache works");
    MTRequestGate *gate=[MTRequestGate new];
    NSUUID *first=[gate beginKey:@"A"]; NSUUID *second=[gate beginKey:@"A"]; NSUUID *b=[gate beginKey:@"B"];
    CHECK(![gate isCurrent:first forKey:@"A"] && [gate isCurrent:second forKey:@"A"],"old result cannot overwrite new request");
    [gate invalidateKey:@"A"];
    CHECK(![gate isCurrent:second forKey:@"A"] && [gate isCurrent:b forKey:@"B"],"restoring A cancels late result without cancelling B");
    if(failures) fprintf(stderr,"%d checks failed\n",failures); else puts("PASS: MIME, encoding, HTML, attachment preservation, isolation and cache checks");
    return failures ? 1:0;
 }
}
