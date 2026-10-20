#import "MIMECore.h"
#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>
#import <libxml/HTMLparser.h>
#import <libxml/HTMLtree.h>
#import <sys/stat.h>

static NSString *Str(NSData *d, NSStringEncoding e){return [[NSString alloc]initWithData:d encoding:e];}
static NSString *Trim(NSString *s){return [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];}
static NSString *Param(NSString *s,NSString *name){
 NSString *p=[NSString stringWithFormat:@"(?:^|;)\\s*%@\\s*=\\s*(?:\"([^\"]*)\"|([^;\\s]+))",name];
 NSTextCheckingResult *m=[[NSRegularExpression regularExpressionWithPattern:p options:NSRegularExpressionCaseInsensitive error:nil]firstMatchInString:s options:0 range:NSMakeRange(0,s.length)];
 if(!m)return nil; NSRange r=[m rangeAtIndex:1];if(r.location==NSNotFound)r=[m rangeAtIndex:2];return [s substringWithRange:r];
}
static NSData *QP(NSData *d){
 NSMutableData *out=[NSMutableData data];const uint8_t *p=d.bytes;
 for(NSUInteger i=0;i<d.length;i++){
  if(p[i]=='='&&i+1<d.length){
   if(p[i+1]=='\n'){i++;continue;}
   if(p[i+1]=='\r'&&i+2<d.length&&p[i+2]=='\n'){i+=2;continue;}
   if(i+2<d.length&&isxdigit(p[i+1])&&isxdigit(p[i+2])){char h[3]={(char)p[i+1],(char)p[i+2],0};uint8_t b=strtoul(h,NULL,16);[out appendBytes:&b length:1];i+=2;continue;}
  }[out appendBytes:p+i length:1];
 }return out;
}
static NSString *Decode(NSData *d,NSString *charset){
 if(charset.length){CFStringEncoding e=CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)charset);return e==kCFStringEncodingInvalidId?nil:Str(d,CFStringConvertEncodingToNSStringEncoding(e));}
 return Str(d,NSUTF8StringEncoding)?:Str(d,NSWindowsCP1252StringEncoding)?:Str(d,NSISOLatin1StringEncoding);
}
static BOOL CanTranslate(NSString *s){
 if(s.length<2||s.length>10000||[s rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location==NSNotFound)return NO;
 if([s hasPrefix:@"http://"]||[s hasPrefix:@"https://"]||[s hasPrefix:@"mailto:"])return NO;
 return !([s containsString:@"@"]&&[s rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location==NSNotFound);
}
static NSString *DecodeHeader(NSString *s){
 s=Str([s dataUsingEncoding:NSISOLatin1StringEncoding],NSUTF8StringEncoding)?:s;
 NSRegularExpression *re=[NSRegularExpression regularExpressionWithPattern:@"=\\?([^?]+)\\?([bBqQ])\\?([^?]*)\\?=" options:0 error:nil];
 NSMutableString *out=s.mutableCopy;
 for(NSTextCheckingResult *m in [[re matchesInString:s options:0 range:NSMakeRange(0,s.length)]reverseObjectEnumerator]){
  NSString *cs=[s substringWithRange:[m rangeAtIndex:1]],*kind=[s substringWithRange:[m rangeAtIndex:2]],*value=[s substringWithRange:[m rangeAtIndex:3]];
  NSData *b=[kind.lowercaseString isEqual:@"b"]?[[NSData alloc]initWithBase64EncodedString:value options:NSDataBase64DecodingIgnoreUnknownCharacters]:QP([[value stringByReplacingOccurrencesOfString:@"_" withString:@" "]dataUsingEncoding:NSISOLatin1StringEncoding]);
  NSString *v=b?Decode(b,cs):nil;if(v)[out replaceCharactersInRange:m.range withString:v];
 }return out;
}
@interface MTPart:NSObject
@property NSData *raw,*header,*body;
@property NSString *newline,*type,*text;
@property NSDictionary *fields;
@property NSMutableArray *chunks,*segments;
@property BOOL protectedContent,malformed,chosen;
+(instancetype)parse:(NSData *)d depth:(NSUInteger)depth;
-(NSArray<MTPart*>*)leaves;
-(NSData*)render:(NSArray*)translations cursor:(NSUInteger*)cursor key:(NSString*)key controls:(BOOL)controls;
@end

static void Collect(xmlNodePtr node,NSMutableArray *nodes,NSMutableArray *texts,BOOL languageRecognition){
 NSSet *excluded=[NSSet setWithArray:@[@"head",@"script",@"style",@"noscript",@"svg",@"math",@"title",@"textarea",@"select",@"pre",@"code"]];
 for(xmlNodePtr n=node;n;n=n->next){
  if(n->type==XML_ELEMENT_NODE){
   NSString *tag=[[NSString stringWithUTF8String:(const char*)n->name]lowercaseString];
   if([excluded containsObject:tag]&&!(languageRecognition&&([tag isEqual:@"pre"]||[tag isEqual:@"code"])))continue;
   xmlChar *st=xmlGetProp(n,BAD_CAST "style"),*hidden=xmlGetProp(n,BAD_CAST "hidden"),*aria=xmlGetProp(n,BAD_CAST "aria-hidden"),*ident=xmlGetProp(n,BAD_CAST "id");
   NSString *style=st?[[NSString stringWithUTF8String:(const char*)st]lowercaseString]:@"";style=[style stringByReplacingOccurrencesOfString:@" " withString:@""];
   BOOL skip=hidden||(aria&&!xmlStrcasecmp(aria,BAD_CAST "true"))||(ident&&!xmlStrcmp(ident,BAD_CAST "mail-translation-controls"))||[style containsString:@"display:none"]||[style containsString:@"visibility:hidden"];
   if(st)xmlFree(st);if(hidden)xmlFree(hidden);if(aria)xmlFree(aria);if(ident)xmlFree(ident);
   if(!skip){
    Collect(n->children,nodes,texts,languageRecognition);
    if(languageRecognition&&[@[@"p",@"div",@"br",@"pre",@"li",@"tr",@"h1",@"h2",@"h3",@"blockquote"]containsObject:tag])[texts addObject:@"\n"];
   }
  }else if(n->type==XML_TEXT_NODE&&n->content){
   NSString *text=Trim([NSString stringWithUTF8String:(const char*)n->content]?:@"");
   if(languageRecognition){[texts addObject:[NSString stringWithUTF8String:(const char*)n->content]?:@""];}
   else if(CanTranslate(text)){[nodes addObject:[NSValue valueWithPointer:n]];[texts addObject:text];}
  }
 }
}
static htmlDocPtr HTML(NSString *s){NSData *d=[s dataUsingEncoding:NSUTF8StringEncoding];return htmlReadMemory(d.bytes,(int)d.length,NULL,"UTF-8",HTML_PARSE_NONET|HTML_PARSE_RECOVER|HTML_PARSE_NOERROR|HTML_PARSE_NOWARNING|HTML_PARSE_NODEFDTD);}
static xmlNodePtr Find(xmlNodePtr n,const char *name){for(;n;n=n->next){if(n->type==XML_ELEMENT_NODE&&!xmlStrcasecmp(n->name,BAD_CAST name))return n;xmlNodePtr c=Find(n->children,name);if(c)return c;}return NULL;}
static NSData *Serialize(htmlDocPtr doc){xmlChar *b=NULL;int count=0;htmlDocDumpMemory(doc,&b,&count);NSData *d=b?[NSData dataWithBytes:b length:count]:nil;if(b)xmlFree(b);return d;}
static void Controls(htmlDocPtr doc,NSString *key,BOOL translated){
 xmlNodePtr body=Find(xmlDocGetRootElement(doc),"body");if(!body)return;
 xmlNodePtr bar=xmlNewNode(NULL,BAD_CAST "div");xmlNewProp(bar,BAD_CAST "id",BAD_CAST "mail-translation-controls");
 xmlNewProp(bar,BAD_CAST "style",BAD_CAST "font-family:-apple-system,sans-serif;font-size:13px;line-height:1.8;padding:10px 14px;margin:0 0 16px;border:1px solid #aab5c3;border-radius:8px;background:#eef3fa;color:#27354b;");
 NSArray *pair=translated?@[@"restore",@"显示原文"]:@[@"translate",@"翻译为中文"];
 {
  xmlNodePtr a=xmlNewChild(bar,NULL,BAD_CAST "a",BAD_CAST[pair[1]UTF8String]);NSString *url=[NSString stringWithFormat:@"mailtranslationprobe://%@/%@",pair[0],key];
  xmlNewProp(a,BAD_CAST "href",BAD_CAST url.UTF8String);xmlNewProp(a,BAD_CAST "style",BAD_CAST "color:#2258a6;text-decoration:underline;margin-right:16px;");xmlAddChild(bar,xmlNewText(BAD_CAST "  "));
 }
 if(body->children)xmlAddPrevSibling(body->children,bar);else xmlAddChild(body,bar);
}
@implementation MTPart
+(instancetype)parse:(NSData*)d depth:(NSUInteger)depth{
 MTPart *p=[MTPart new];p.raw=d;p.chunks=[NSMutableArray new];p.segments=[NSMutableArray new];
 if(depth>20){p.malformed=YES;return p;}
 NSString *all=Str(d,NSISOLatin1StringEncoding);NSRange cr=[all rangeOfString:@"\r\n\r\n"],lf=[all rangeOfString:@"\n\n"];
 NSRange sep=cr.location!=NSNotFound&&(lf.location==NSNotFound||cr.location<lf.location)?cr:lf;
 if(sep.location==NSNotFound){p.malformed=YES;return p;}
 p.newline=sep.length==4?@"\r\n":@"\n";p.header=[d subdataWithRange:NSMakeRange(0,sep.location)];p.body=[d subdataWithRange:NSMakeRange(NSMaxRange(sep),d.length-NSMaxRange(sep))];
 NSMutableDictionary *fields=[NSMutableDictionary new];NSString *current=nil;
 for(NSString *line in [[Str(p.header,NSISOLatin1StringEncoding)stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]componentsSeparatedByString:@"\n"]){
  if(([line hasPrefix:@" "]||[line hasPrefix:@"\t"])&&current){fields[current]=[fields[current]stringByAppendingFormat:@" %@",Trim(line)];continue;}
  NSRange colon=[line rangeOfString:@":"];if(colon.location==NSNotFound){current=nil;continue;}current=[[line substringToIndex:colon.location]lowercaseString];fields[current]=Trim([line substringFromIndex:NSMaxRange(colon)]);
 }
 p.fields=fields;NSString *ct=fields[@"content-type"]?:@"text/plain";p.type=Trim([[ct componentsSeparatedByString:@";"]firstObject]).lowercaseString;
 NSString *disposition=[fields[@"content-disposition"]lowercaseString]?:@"";
 // An attachment is opaque even when its MIME type is itself multipart.
 if([disposition hasPrefix:@"attachment"]||Param(disposition,@"filename").length||Param(ct,@"name").length)return p;
 if([@[@"multipart/signed",@"multipart/encrypted",@"application/pkcs7-mime",@"application/x-pkcs7-mime",@"application/pgp-encrypted",@"application/pgp-signature",@"application/pkcs7-signature"]containsObject:p.type]){p.protectedContent=YES;return p;}
 if([p.type hasPrefix:@"multipart/"]){
  NSString *boundary=Param(ct,@"boundary");if(!boundary.length||boundary.length>200){p.malformed=YES;return p;}
  NSString *s=Str(p.body,NSISOLatin1StringEncoding),*pattern=[NSString stringWithFormat:@"(?m)^--%@(?:--)?[\\t ]*(?:\\r?\\n|$)",[NSRegularExpression escapedPatternForString:boundary]];
  NSArray *matches=[[NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil]matchesInString:s options:0 range:NSMakeRange(0,s.length)];
  if(matches.count<2){p.malformed=YES;return p;}
  NSUInteger pos=0;BOOL closed=NO;
  for(NSUInteger i=0;i<matches.count;i++){
   NSTextCheckingResult *m=matches[i];if(m.range.location>pos)[p.chunks addObject:[p.body subdataWithRange:NSMakeRange(pos,m.range.location-pos)]];
   [p.chunks addObject:[p.body subdataWithRange:m.range]];pos=NSMaxRange(m.range);
   if([[s substringWithRange:m.range]hasPrefix:[NSString stringWithFormat:@"--%@--",boundary]]){closed=YES;break;}
   if(i+1>=matches.count){p.malformed=YES;break;}
   NSTextCheckingResult *next=matches[i+1];MTPart *child=[MTPart parse:[p.body subdataWithRange:NSMakeRange(pos,next.range.location-pos)]depth:depth+1];
   [p.chunks addObject:child];pos=next.range.location;p.protectedContent|=child.protectedContent;p.malformed|=child.malformed;
  }
  if(!closed)p.malformed=YES;if(pos<p.body.length)[p.chunks addObject:[p.body subdataWithRange:NSMakeRange(pos,p.body.length-pos)]];return p;
 }
 if(!([p.type isEqual:@"text/html"]||[p.type isEqual:@"text/plain"]))return p;
 NSString *disp=[fields[@"content-disposition"]lowercaseString]?:@"";
 if([disp hasPrefix:@"attachment"]||Param(disp,@"filename").length||Param(ct,@"name").length)return p;
 NSData *decoded=p.body;NSString *transfer=[fields[@"content-transfer-encoding"]lowercaseString];
 if([transfer isEqual:@"base64"])decoded=[[NSData alloc]initWithBase64EncodedData:decoded options:NSDataBase64DecodingIgnoreUnknownCharacters];
 else if([transfer isEqual:@"quoted-printable"])decoded=QP(decoded);else if(transfer.length&&![@[@"7bit",@"8bit",@"binary"]containsObject:transfer])return p;
 if(decoded)p.text=Decode(decoded,Param(ct,@"charset"));
 if([p.text containsString:@"-----BEGIN PGP "]){p.protectedContent=YES;p.text=nil;}return p;
}
-(NSArray*)leaves{NSMutableArray *a=[NSMutableArray new];if(self.text)[a addObject:self];for(id c in self.chunks)if([c isKindOfClass:MTPart.class])[a addObjectsFromArray:[c leaves]];return a;}
-(NSData*)encode:(NSData*)content html:(BOOL)isHTML{
 NSMutableArray *kept=[NSMutableArray new];BOOL skip=NO;
 for(NSString *line in [[Str(self.header,NSISOLatin1StringEncoding)stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]componentsSeparatedByString:@"\n"]){
  if(!([line hasPrefix:@" "]||[line hasPrefix:@"\t"])){NSString *name=[[[line componentsSeparatedByString:@":"]firstObject]lowercaseString];skip=[@[@"content-type",@"content-transfer-encoding",@"content-length"]containsObject:name];}
  if(!skip)[kept addObject:line];
 }
 [kept addObject:[NSString stringWithFormat:@"Content-Type: %@; charset=utf-8",isHTML?@"text/html":@"text/plain"]];[kept addObject:@"Content-Transfer-Encoding: base64"];
 NSMutableString *out=[[kept componentsJoinedByString:self.newline]mutableCopy];[out appendFormat:@"%@%@",self.newline,self.newline];
 NSString *b64=[content base64EncodedStringWithOptions:0];for(NSUInteger i=0;i<b64.length;i+=76)[out appendFormat:@"%@%@",[b64 substringWithRange:NSMakeRange(i,MIN(76,b64.length-i))],self.newline];
 return [out dataUsingEncoding:NSISOLatin1StringEncoding];
}
-(NSData*)render:(NSArray*)translations cursor:(NSUInteger*)cursor key:(NSString*)key controls:(BOOL)controls{
 if(self.chunks.count){NSMutableData *d=self.header.mutableCopy;[d appendData:[[self.newline stringByAppendingString:self.newline]dataUsingEncoding:NSUTF8StringEncoding]];for(id c in self.chunks){NSData *v=[c isKindOfClass:MTPart.class]?[c render:translations cursor:cursor key:key controls:controls]:c;if(!v)return nil;[d appendData:v];}return d;}
 if(!self.chosen||(!translations&&!controls))return self.raw;
 if([self.type isEqual:@"text/html"]){
  htmlDocPtr doc=HTML(self.text);if(!doc)return nil;NSMutableArray *nodes=[NSMutableArray new],*texts=[NSMutableArray new];Collect(xmlDocGetRootElement(doc),nodes,texts,NO);
  if(translations)for(NSValue *value in nodes){
   if(*cursor>=translations.count){xmlFreeDoc(doc);return nil;}xmlNodePtr n=value.pointerValue;NSString *old=[NSString stringWithUTF8String:(const char*)n->content]?:@"";NSRange r=[old rangeOfString:Trim(old)];
   NSString *value=[NSString stringWithFormat:@"%@%@%@",[old substringToIndex:r.location],translations[(*cursor)++],[old substringFromIndex:NSMaxRange(r)]];xmlNodeSetContent(n,BAD_CAST value.UTF8String);
  }
  if(controls)Controls(doc,key,translations!=nil);NSData *out=Serialize(doc);xmlFreeDoc(doc);return out?[self encode:out html:YES]:nil;
 }
 NSString *text=self.text;
 if(translations&&self.segments.count){if(*cursor>=translations.count)return nil;text=translations[(*cursor)++];}
 if(!controls)return [self encode:[text dataUsingEncoding:NSUTF8StringEncoding]html:NO];
 htmlDocPtr doc=HTML(@"<html><body><div style='white-space:pre-wrap;font-family:-apple-system,sans-serif;line-height:1.6'></div></body></html>");
 xmlNodePtr div=Find(xmlDocGetRootElement(doc),"div");xmlNodeSetContent(div,BAD_CAST text.UTF8String);Controls(doc,key,translations!=nil);NSData *out=Serialize(doc);xmlFreeDoc(doc);return out?[self encode:out html:YES]:nil;
}
@end

@interface MTMessage()
@property(readwrite,copy)NSData *original;
@property(readwrite,copy)NSString *key,*subject;
@property(readwrite)BOOL eligible;
@property(readwrite,copy)NSArray<NSString*>*texts;
@property(nonatomic,strong)MTPart *root;
@end
static NSArray<MTPart*> *BodyParts(MTPart *part){
 if(part.text)return @[part];
 NSMutableArray<MTPart*> *children=[NSMutableArray new];
 for(id chunk in part.chunks)if([chunk isKindOfClass:MTPart.class])[children addObject:chunk];
 if([part.type isEqual:@"multipart/related"]){
  NSString *start=Param(part.fields[@"content-type"]?:@"",@"start");
  if(start.length){for(MTPart *child in children)if([Trim(child.fields[@"content-id"]?:@"")isEqual:start])return BodyParts(child);return @[];}
  return children.count?BodyParts(children.firstObject):@[];
 }
 if([part.type isEqual:@"multipart/alternative"]){
  NSArray *best=@[];NSUInteger bestScore=0;
  // Prefer the last supported HTML alternative, otherwise the last text alternative.
  for(MTPart *child in children){
   NSArray *candidate=BodyParts(child);NSUInteger score=candidate.count?1:0;
   for(MTPart *leaf in candidate)if([leaf.type isEqual:@"text/html"])score=2;
   if(score&&score>=bestScore){best=candidate;bestScore=score;}
  }return best;
 }
 NSMutableArray *parts=[NSMutableArray new];for(MTPart *child in children)[parts addObjectsFromArray:BodyParts(child)];return parts;
}
static NSArray *Choose(MTPart *root){
 NSMutableArray *texts=[NSMutableArray new];
 for(MTPart *part in BodyParts(root)){
  part.chosen=YES;[part.segments removeAllObjects];
  if([part.type isEqual:@"text/html"]){htmlDocPtr doc=HTML(part.text);if(doc){Collect(xmlDocGetRootElement(doc),[NSMutableArray new],part.segments,NO);xmlFreeDoc(doc);}}
  else if(CanTranslate(Trim(part.text)))[part.segments addObject:Trim(part.text)];
  [texts addObjectsFromArray:part.segments];
 }return texts;
}
// Add a separate inline MIME part; never rewrite/reserialize the original body.
static NSData *OriginalWithControls(MTMessage *message){
 MTPart *root=[MTPart parse:message.original depth:0];if(root.malformed)return nil;
 NSString *boundary=nil;
 do {boundary=[@"mail-translation-original-" stringByAppendingString:NSUUID.UUID.UUIDString];}
 while([message.original rangeOfData:[boundary dataUsingEncoding:NSASCIIStringEncoding] options:0 range:NSMakeRange(0,message.original.length)].location!=NSNotFound);
 NSString *nl=root.newline;NSMutableArray *headers=[NSMutableArray new];BOOL skip=NO;
 for(NSString *line in [[Str(root.header,NSISOLatin1StringEncoding)stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"]componentsSeparatedByString:@"\n"]){
  if(!([line hasPrefix:@" "]||[line hasPrefix:@"\t"])){NSString *name=[[[line componentsSeparatedByString:@":"]firstObject]lowercaseString];skip=[name hasPrefix:@"content-"];}
  if(!skip)[headers addObject:line];
 }
 if(!root.fields[@"mime-version"])[headers addObject:@"MIME-Version: 1.0"];
 [headers addObject:[NSString stringWithFormat:@"Content-Type: multipart/mixed; boundary=\"%@\"",boundary]];
 [headers addObject:@"Content-Transfer-Encoding: 8bit"];
 NSMutableData *out=[[[headers componentsJoinedByString:nl]stringByAppendingFormat:@"%@%@",nl,nl]dataUsingEncoding:NSISOLatin1StringEncoding].mutableCopy;
 htmlDocPtr doc=HTML(@"<html><body></body></html>");if(!doc)return nil;
 // Mail combines inline HTML parts under the first body. Carry presentation
 // attributes into that body while preserving the source part byte-for-byte.
 xmlNodePtr controlBody=Find(xmlDocGetRootElement(doc),"body");
 for(MTPart *part in BodyParts(root))if([part.type isEqual:@"text/html"]){
  htmlDocPtr sourceDoc=HTML(part.text);
  if(sourceDoc){xmlNodePtr body=Find(xmlDocGetRootElement(sourceDoc),"body");
   if(body){for(NSString *name in @[@"style",@"class",@"id",@"dir",@"lang",@"bgcolor",@"text",@"link",@"vlink",@"alink",@"background"]){
    xmlChar *value=xmlGetProp(body,BAD_CAST name.UTF8String);if(value){xmlNewProp(controlBody,BAD_CAST name.UTF8String,value);xmlFree(value);}
   }}
   xmlFreeDoc(sourceDoc);
  }break;
 }
 Controls(doc,message.key,NO);NSData *bar=Serialize(doc);xmlFreeDoc(doc);if(!bar)return nil;
 NSString *part=[NSString stringWithFormat:@"--%@%@Content-Type: text/html; charset=utf-8%@Content-Disposition: inline%@Content-Transfer-Encoding: base64%@%@",boundary,nl,nl,nl,nl,nl];
 [out appendData:[part dataUsingEncoding:NSASCIIStringEncoding]];
 NSString *b64=[bar base64EncodedStringWithOptions:0];for(NSUInteger i=0;i<b64.length;i+=76)[out appendData:[[NSString stringWithFormat:@"%@%@",[b64 substringWithRange:NSMakeRange(i,MIN(76,b64.length-i))],nl]dataUsingEncoding:NSASCIIStringEncoding]];
 [out appendData:[[NSString stringWithFormat:@"--%@%@",boundary,nl]dataUsingEncoding:NSASCIIStringEncoding]];
 [out appendData:message.original];
 [out appendData:[[NSString stringWithFormat:@"%@--%@--%@",nl,boundary,nl]dataUsingEncoding:NSASCIIStringEncoding]];
 return out;
}
@implementation MTMessage
+(NSString*)keyForData:(NSData*)d{unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,digest);NSMutableString *s=[NSMutableString new];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[s appendFormat:@"%02x",digest[i]];return s;}
 +(instancetype)messageWithData:(NSData*)d{
  if(!d.length||d.length>10*1024*1024)return nil;MTMessage *m=[MTMessage new];m.original=d;m.key=[self keyForData:d];MTPart *root=[MTPart parse:d depth:0];m.root=root;
  m.subject=DecodeHeader(root.fields[@"subject"]?:@"（无主题）");m.texts=(!root.malformed&&!root.protectedContent)?Choose(root):@[];
  NSUInteger count=0;for(NSString *s in m.texts)count+=s.length;m.eligible=m.texts.count>0&&m.texts.count<=1024&&count<=200000;return m;
 }
 -(NSData*)renderTranslations:(NSArray*)translations includeControls:(BOOL)controls{
  if(!self.eligible)return nil;if(translations&&(![translations isKindOfClass:NSArray.class]||translations.count!=self.texts.count))return nil;
  for(id v in translations)if(![v isKindOfClass:NSString.class]||[v length]>40000)return nil;
  if(!translations&&!controls)return self.original;if(!translations&&controls)return OriginalWithControls(self);MTPart *root=self.root?:[MTPart parse:self.original depth:0];Choose(root);NSUInteger cursor=0;return [root render:translations cursor:&cursor key:self.key controls:controls];
 }
 -(NSString*)bodyTextForLanguageRecognition{
  MTPart *root=self.root?:[MTPart parse:self.original depth:0];if(root.malformed||root.protectedContent)return @"";
 NSMutableString *body=[NSMutableString new];
 for(MTPart *part in BodyParts(root)){
  NSString *text=part.text;
  if([part.type isEqual:@"text/html"]){
   htmlDocPtr doc=HTML(text);NSMutableArray *texts=[NSMutableArray new];
   if(doc){Collect(xmlDocGetRootElement(doc),nil,texts,YES);xmlFreeDoc(doc);}text=[texts componentsJoinedByString:@""];
  }
  if(body.length)[body appendString:@"\n"];
  NSUInteger remaining=20000-body.length;
  [body appendString:text.length>remaining?[text substringToIndex:remaining]:text];
  if(body.length>=20000)break;
 }return body;
}
@end

@interface MTCache()
@property(readwrite,strong)NSURL *root;
@end
@implementation MTCache
-(instancetype)initWithRoot:(NSURL*)root{if((self=[super init])){_root=root;[NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700}error:nil];chmod(root.fileSystemRepresentation,0700);}return self;}
+(BOOL)isValidKey:(NSString*)key{return [key isKindOfClass:NSString.class]&&key.length==64&&[key rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"]invertedSet]].location==NSNotFound;}
-(NSURL*)path:(NSString*)key suffix:(NSString*)suffix{return [MTCache isValidKey:key]?[self.root URLByAppendingPathComponent:[key stringByAppendingString:suffix]]:nil;}
-(NSDictionary*)safeAttributes:(NSURL*)url maxSize:(unsigned long long)maxSize{
 if(!url)return nil;NSNumber *link=nil;
 if(![url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil]||link.boolValue)return nil;
 NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil];
 if(![attrs[NSFileType]isEqual:NSFileTypeRegular])return nil;
 unsigned long long size=[attrs[NSFileSize]unsignedLongLongValue];
 if(!size||(maxSize&&size>maxSize))return nil;return attrs;
}
-(BOOL)hasFile:(NSURL*)url maxSize:(unsigned long long)maxSize{return [self safeAttributes:url maxSize:maxSize]!=nil;}
-(NSData*)safeRead:(NSURL*)url maxSize:(unsigned long long)maxSize{
 if(![self hasFile:url maxSize:maxSize])return nil;return [NSData dataWithContentsOfURL:url];
}
-(NSData*)safeRead:(NSURL*)url{return [self safeRead:url maxSize:16*1024*1024];}
-(NSDictionary*)metadata:(NSString*)key{
 NSData *d=[self safeRead:[self path:key suffix:@".plist"] maxSize:256*1024];if(!d)return nil;id p=[NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:nil];
 if(![p isKindOfClass:NSDictionary.class]||![p[@"timestamp"]isKindOfClass:NSNumber.class]||![p[@"subject"]isKindOfClass:NSString.class])return nil;
 NSTimeInterval age=NSDate.date.timeIntervalSince1970-[p[@"timestamp"]doubleValue];return age>=-60&&age<=1800?p:nil;
}
-(BOOL)write:(NSData*)d url:(NSURL*)url{if(!url||![d writeToURL:url options:NSDataWritingAtomic error:nil])return NO;chmod(url.fileSystemRepresentation,0600);return YES;}
-(void)removeKey:(NSString*)key{for(NSString *s in @[@".source.eml",@".display.eml",@".plist",@".original",@".translated",@".translatable"]){NSURL *u=[self path:key suffix:s];if(u)[NSFileManager.defaultManager removeItemAtURL:u error:nil];}}
-(NSArray*)recentMessages{
 @synchronized(MTCache.class){
  NSMutableArray *items=[NSMutableArray new];
  for(NSURL *u in [NSFileManager.defaultManager contentsOfDirectoryAtURL:self.root includingPropertiesForKeys:nil options:0 error:nil]){
   if(![u.pathExtension isEqual:@"plist"])continue;NSString *key=u.lastPathComponent.stringByDeletingPathExtension;if(![MTCache isValidKey:key])continue;
   NSDictionary *meta=[self metadata:key];if(!meta){[self removeKey:key];continue;}
   BOOL source=[self hasFile:[self path:key suffix:@".source.eml"] maxSize:16*1024*1024];
   BOOL original=source&&[self hasFile:[self path:key suffix:@".original"] maxSize:4096];
   BOOL display=source&&[self hasFile:[self path:key suffix:@".display.eml"] maxSize:16*1024*1024];
   [items addObject:@{@"key":key,@"subject":meta[@"subject"],@"timestamp":meta[@"timestamp"],@"translated":@(display),@"original":@(original)}];
  }
  [items sortUsingComparator:^NSComparisonResult(NSDictionary*a,NSDictionary*b){return [b[@"timestamp"]compare:a[@"timestamp"]];}];
  while(items.count>20){[self removeKey:[items.lastObject objectForKey:@"key"]];[items removeLastObject];}return items;
 }
}
-(BOOL)rememberMessage:(MTMessage*)m changed:(BOOL*)changed{
 if(changed)*changed=NO;if(!m.eligible||![MTCache isValidKey:m.key])return NO;
 @synchronized(MTCache.class){
  NSURL *source=[self path:m.key suffix:@".source.eml"];NSDictionary *meta=[self metadata:m.key];
  if(![self hasFile:source maxSize:16*1024*1024]||!meta){
   // Never let fresh metadata revive an expired or missing source/display.
   [self removeKey:m.key];meta=nil;
   if(![self write:m.original url:source])return NO;
   if(changed)*changed=YES;
  }
  NSTimeInterval now=NSDate.date.timeIntervalSince1970;
  if(!meta||now-[meta[@"timestamp"]doubleValue]>=60){
   NSString *subject=m.subject.length>300?[m.subject substringToIndex:300]:m.subject;
   NSData *data=[NSPropertyListSerialization dataWithPropertyList:@{@"subject":subject,@"timestamp":@(now)}format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
   if(![self write:data url:[self path:m.key suffix:@".plist"]])return NO;
   if(changed)*changed=YES;
  }
  (void)[self recentMessages];return YES;
 }
}
-(BOOL)rememberMessage:(MTMessage*)m{return [self rememberMessage:m changed:NULL];}
-(NSString*)subjectForKey:(NSString*)key{return [self metadata:key][@"subject"];}
-(BOOL)hasSourceForKey:(NSString*)key{return [self metadata:key]!=nil&&[self hasFile:[self path:key suffix:@".source.eml"] maxSize:16*1024*1024];}
-(BOOL)hasTranslatableSourceForKey:(NSString*)key{return [self hasSourceForKey:key]&&[self hasFile:[self path:key suffix:@".translatable"] maxSize:4096];}
-(BOOL)markTranslatableSourceForKey:(NSString*)key{
 @synchronized(MTCache.class){
  if(![self hasSourceForKey:key])return NO;
  return [self hasFile:[self path:key suffix:@".translatable"] maxSize:4096]||[self write:[@"translatable" dataUsingEncoding:NSUTF8StringEncoding] url:[self path:key suffix:@".translatable"]];
 }
}
-(BOOL)hasStoredDisplayForKey:(NSString*)key{return [self hasSourceForKey:key]&&[self hasFile:[self path:key suffix:@".display.eml"] maxSize:16*1024*1024];}
-(BOOL)hasTranslatedDisplayForKey:(NSString*)key{
 return [self hasStoredDisplayForKey:key]&&[self hasFile:[self path:key suffix:@".translated"] maxSize:4096]&&![self hasFile:[self path:key suffix:@".original"] maxSize:4096];
}
-(BOOL)activateStoredDisplayForKey:(NSString*)key{
 @synchronized(MTCache.class){
  if(![self hasStoredDisplayForKey:key])return NO;
  if(![self write:[@"translated" dataUsingEncoding:NSUTF8StringEncoding] url:[self path:key suffix:@".translated"]])return NO;
  NSURL *marker=[self path:key suffix:@".original"];
  return ![self hasFile:marker maxSize:4096]||[NSFileManager.defaultManager removeItemAtURL:marker error:nil];
 }
}
-(NSData*)sourceForKey:(NSString*)key{
 if(![self metadata:key])return nil;NSData *d=[self safeRead:[self path:key suffix:@".source.eml"]];return d&&[[MTMessage keyForData:d]isEqual:key]?d:nil;
}
-(NSData*)storedDisplayForKey:(NSString*)key{return [self hasSourceForKey:key]?[self safeRead:[self path:key suffix:@".display.eml"]]:nil;}
-(NSData*)displayForKey:(NSString*)key{return [self hasTranslatedDisplayForKey:key]?[self storedDisplayForKey:key]:nil;}
-(BOOL)setDisplay:(NSData*)d forKey:(NSString*)key{return [self setDisplay:d forKey:key activate:YES];}
-(BOOL)setDisplay:(NSData*)d forKey:(NSString*)key activate:(BOOL)activate{
 @synchronized(MTCache.class){
  if(![self hasSourceForKey:key]||d.length>16*1024*1024||![self write:d url:[self path:key suffix:@".display.eml"]])return NO;
  if(!activate)return YES;
  if(![self write:[@"translated" dataUsingEncoding:NSUTF8StringEncoding] url:[self path:key suffix:@".translated"]])return NO;
  NSURL *marker=[self path:key suffix:@".original"];
  return ![self hasFile:marker maxSize:4096]||[NSFileManager.defaultManager removeItemAtURL:marker error:nil];
 }
}
-(BOOL)prefersOriginalForKey:(NSString*)key{return [self hasSourceForKey:key]&&[self hasFile:[self path:key suffix:@".original"] maxSize:4096];}
-(void)restoreKey:(NSString*)key{
 @synchronized(MTCache.class){
  if(![self hasSourceForKey:key])return;
  [self write:[@"original" dataUsingEncoding:NSUTF8StringEncoding] url:[self path:key suffix:@".original"]];
  NSURL *translated=[self path:key suffix:@".translated"];if(translated)[NSFileManager.defaultManager removeItemAtURL:translated error:nil];
 }
}
-(void)clear{
 @synchronized(MTCache.class){
  for(NSURL *u in [NSFileManager.defaultManager contentsOfDirectoryAtURL:self.root includingPropertiesForKeys:nil options:0 error:nil]){NSString *n=u.lastPathComponent;if(n.length>64&&[MTCache isValidKey:[n substringToIndex:64]])[NSFileManager.defaultManager removeItemAtURL:u error:nil];}
 }
}
@end
@implementation MTRequestGate{NSMutableDictionary<NSString*,NSUUID*>*_tokens;}
-(instancetype)init{if((self=[super init]))_tokens=[NSMutableDictionary new];return self;}
-(NSUUID*)beginKey:(NSString*)key{NSUUID *token=NSUUID.UUID;_tokens[key]=token;return token;}
-(void)invalidateKey:(NSString*)key{[_tokens removeObjectForKey:key];}
-(BOOL)isCurrent:(NSUUID*)token forKey:(NSString*)key{return [_tokens[key]isEqual:token];}
@end


@implementation MTTranslationQueue {
 NSMutableArray<NSString*> *_pending;
 NSMutableDictionary<NSString*,NSNumber*> *_attempted;
 NSTimeInterval (^_clock)(void);
}
-(instancetype)init{return [self initWithClock:^{return NSDate.date.timeIntervalSince1970;}];}
-(instancetype)initWithClock:(NSTimeInterval (^)(void))clock{
 if((self=[super init])){_pending=[NSMutableArray new];_attempted=[NSMutableDictionary new];_clock=[clock copy];}return self;
}
-(void)enqueueKey:(NSString*)key{
 NSTimeInterval now=_clock();
 for(NSString *old in _attempted.allKeys)if(now-[_attempted[old]doubleValue]>=1800||now<[_attempted[old]doubleValue])[_attempted removeObjectForKey:old];
 if([MTCache isValidKey:key]&&!_attempted[key]&&![_pending containsObject:key])[_pending addObject:key];
}
-(NSString*)takeNextKey{
 NSString *key=_pending.firstObject;if(key){[_pending removeObjectAtIndex:0];_attempted[key]=@(_clock());}return key;
}
-(void)completeKey:(NSString*)key{if([MTCache isValidKey:key]){[_pending removeObject:key];[_attempted removeObjectForKey:key];}}
-(void)cancelKey:(NSString*)key{if([MTCache isValidKey:key]){[_pending removeObject:key];_attempted[key]=@(_clock());}}
@end
