#import "MTSetupController.h"
#import "MTAppManagement.h"
@interface MTSetupController ()
@property(nonatomic) NSUserDefaults *preferences;
@property(nonatomic) NSTextField *mailStatus;
@property(nonatomic) NSTextField *extensionStatus;
@property(nonatomic) NSTextField *modelStatus;
@property(nonatomic) NSTextField *feedback;
@property(nonatomic) NSButton *lifecycleToggle;
@property(nonatomic) NSButton *uninstallButton;
@property(nonatomic) BOOL refreshing;
@property(nonatomic) BOOL managing;
@end
@implementation MTSetupController
- (instancetype)initWithPreferences:(NSUserDefaults *)preferences {
 if((self=[super initWithWindow:nil])){_preferences=preferences;_management=[MTAppManagement new];}return self;
}
- (BOOL)needsSetup{return ![self.preferences boolForKey:@"MTSetupCompleted"];}
- (NSTextField *)label:(NSString *)text font:(NSFont *)font {
 NSTextField *label=[NSTextField wrappingLabelWithString:text];label.font=font;label.selectable=YES;label.maximumNumberOfLines=0;return label;
}
- (NSButton *)button:(NSString *)title action:(SEL)action {NSButton *button=[NSButton buttonWithTitle:title target:self action:action];button.bezelStyle=NSBezelStyleRounded;return button;}
- (NSStackView *)row:(NSArray<NSView *> *)views {
 NSStackView *row=[NSStackView stackViewWithViews:views];row.orientation=NSUserInterfaceLayoutOrientationHorizontal;row.spacing=8;row.alignment=NSLayoutAttributeCenterY;return row;
}
- (void)addSection:(NSString *)title detail:(NSString *)detail status:(NSTextField **)status buttons:(NSArray *)buttons to:(NSStackView *)stack {
 [stack addArrangedSubview:[self label:title font:[NSFont boldSystemFontOfSize:13]]];
 NSTextField *line=[self label:detail font:[NSFont systemFontOfSize:12]];line.textColor=NSColor.secondaryLabelColor;[stack addArrangedSubview:line];if(status)*status=line;
 if(buttons.count)[stack addArrangedSubview:[self row:buttons]];
}
- (void)loadSetupWindow {
 NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,650,555)styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
 window.title=@"MailTrans 设置";window.releasedWhenClosed=NO;window.delegate=self;[window center];self.window=window;
 NSStackView *stack=[NSStackView new];stack.orientation=NSUserInterfaceLayoutOrientationVertical;stack.alignment=NSLayoutAttributeLeading;stack.spacing=9;stack.translatesAutoresizingMaskIntoConstraints=NO;
 [window.contentView addSubview:stack];[NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:window.contentView.leadingAnchor constant:24],[stack.trailingAnchor constraintEqualToAnchor:window.contentView.trailingAnchor constant:-24],[stack.topAnchor constraintEqualToAnchor:window.contentView.topAnchor constant:20]]];
 [stack addArrangedSubview:[self label:@"在 Apple 邮件中阅读中文译文" font:[NSFont boldSystemFontOfSize:21]]];
 NSTextField *intro=[self label:@"翻译在本机完成。原邮件与附件保留；日常操作在菜单栏的 MailTrans 图标中。" font:[NSFont systemFontOfSize:12]];intro.textColor=NSColor.secondaryLabelColor;[stack addArrangedSubview:intro];
 NSTextField *install=[self label:@"首次使用：先将 MailTrans.app 移到“应用程序”文件夹，再从该位置打开。自动启动需要固定的安装位置。" font:[NSFont systemFontOfSize:11]];install.textColor=NSColor.secondaryLabelColor;[stack addArrangedSubview:install];
 NSTextField *mail=nil,*extension=nil,*model=nil;
 [self addSection:@"1 · 打开“邮件”" detail:@"正在检查“邮件”状态…" status:&mail buttons:@[[self button:@"打开“邮件”" action:@selector(openMail:)]] to:stack];self.mailStatus=mail;
 [self addSection:@"2 · 启用 MailTrans 扩展" detail:@"在“邮件”→“设置”→“扩展”中勾选 MailTrans。" status:&extension buttons:@[[self button:@"查看启用步骤" action:@selector(showExtensionHelp:)]] to:stack];self.extensionStatus=extension;
 [self addSection:@"3 · 准备本地英中语言包" detail:@"正在检查语言包…" status:&model buttons:@[[self button:@"准备英中语言包" action:@selector(prepareLanguage:)],[self button:@"刷新状态" action:@selector(refresh:)]] to:stack];self.modelStatus=model;
 self.lifecycleToggle=[NSButton checkboxWithTitle:@"随“邮件”自动启动和退出（可选）" target:self action:@selector(toggleLifecycle:)];self.lifecycleToggle.enabled=NO;[stack addArrangedSubview:self.lifecycleToggle];
 NSTextField *automatic=[self label:@"启用后，一个轻量观察程序会等待“邮件”启动。自动翻译可在菜单栏单独暂停。" font:[NSFont systemFontOfSize:11]];automatic.textColor=NSColor.secondaryLabelColor;[stack addArrangedSubview:automatic];
 [stack addArrangedSubview:[self row:@[[self button:@"打开示例邮件" action:@selector(openSample:)],[self button:@"检查更新" action:@selector(openReleases:)],[self button:@"使用帮助" action:@selector(openHelp:)]]]];
 self.feedback=[self label:@"检查更新会打开 GitHub Releases；不会自动下载或替换应用。" font:[NSFont systemFontOfSize:11]];self.feedback.textColor=NSColor.secondaryLabelColor;[stack addArrangedSubview:self.feedback];
 self.uninstallButton=[self button:@"卸载 MailTrans…" action:@selector(confirmUninstall:)];self.uninstallButton.enabled=NO;self.uninstallButton.toolTip=@"请先退出“邮件”，然后刷新状态再卸载。";
 [stack addArrangedSubview:[self row:@[self.uninstallButton,[self button:@"完成设置" action:@selector(finishSetup:)]]]];
 // Pin wrapping labels to the content width so accessibility text never overflows.
 for(NSView *view in stack.arrangedSubviews)if([view isKindOfClass:NSTextField.class])[view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
}
- (void)showWindow {if(!self.window)[self loadSetupWindow];[NSApp activateIgnoringOtherApps:YES];[self.window makeKeyAndOrderFront:nil];[self refresh:nil];}
- (void)windowDidBecomeKey:(NSNotification *)notification {[self refresh:nil];}
- (void)markSetupComplete {[self.preferences setBool:YES forKey:@"MTSetupCompleted"];}
- (void)finishSetup:(id)sender {[self markSetupComplete];[self.window close];}
- (void)refresh:(id)sender {
 if(self.refreshing||self.managing)return;self.refreshing=YES;
 MTAppManagement *management=self.management;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
  NSDictionary *snapshot=[management statusSnapshot];
  dispatch_async(dispatch_get_main_queue(),^{
   self.refreshing=NO;if(self.managing)return;
   self.uninstallButton.enabled=![snapshot[@"mailRunning"]boolValue];
   self.mailStatus.stringValue=[snapshot[@"mailRunning"]boolValue]?@"“邮件”正在运行。":@"“邮件”尚未打开；可以先完成下面的设置。";
   self.extensionStatus.stringValue=[snapshot[@"extensionRegistered"]boolValue]?@"此应用的扩展已注册。请在“邮件”→“设置”→“扩展”中确认已勾选 MailTrans。":@"尚未确认此应用的扩展注册。请打开“邮件”，在“设置”→“扩展”中勾选 MailTrans。";
   NSString *state=snapshot[@"modelStatus"];
   self.modelStatus.stringValue=[state isEqual:@"installed"]?@"英中语言包已安装，可离线翻译。":([state isEqual:@"supported"]?@"需要下载英中语言包；点“准备英中语言包”继续。":([state isEqual:@"unsupported"]?@"此系统不支持英中语言组合，请检查系统版本与语言设置。":@"暂时无法检查语言包。可点“准备英中语言包”，完成后刷新状态。"));
   self.lifecycleToggle.state=[snapshot[@"automaticLaunch"]isEqual:@"enabled"]?NSControlStateValueOn:NSControlStateValueOff;self.lifecycleToggle.enabled=![snapshot[@"automaticLaunch"]isEqual:@"unknown"];if(!self.lifecycleToggle.enabled)[self showError:@"自动启动状态暂不可用，请点“刷新状态”重试。" ];
  });
 });
}
- (void)openMail:(id)sender {
 NSWorkspaceOpenConfiguration *config=NSWorkspaceOpenConfiguration.configuration;
 [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:@"/System/Applications/Mail.app"]configuration:config completionHandler:^(NSRunningApplication *app,NSError *error){dispatch_async(dispatch_get_main_queue(),^{if(error)[self showError:@"无法打开“邮件”。请从“应用程序”文件夹打开后再刷新。" ];else [self refresh:nil];});}];
}
- (void)showExtensionHelp:(id)sender {
 NSAlert *alert=[NSAlert new];alert.messageText=@"在“邮件”中启用 MailTrans";alert.informativeText=@"打开“邮件”→“设置”→“扩展”，勾选 MailTrans，并确认系统提示。注册状态不能证明扩展已启用。若列表中没有 MailTrans，请退出“邮件”、重新打开此应用，再打开“邮件”检查。";[alert addButtonWithTitle:@"知道了"];[alert beginSheetModalForWindow:self.window completionHandler:nil];
}
- (void)prepareLanguage:(id)sender {if(self.languagePreparationHandler){self.feedback.stringValue=@"请在语言包窗口完成下载，然后回来刷新状态。";self.languagePreparationHandler();}else [self showError:@"语言包准备暂不可用，请重新打开 MailTrans。" ];}
- (void)showError:(NSString *)message {self.feedback.textColor=NSColor.systemRedColor;self.feedback.stringValue=message;}
- (void)toggleLifecycle:(id)sender {
 if(self.managing)return;BOOL enable=self.lifecycleToggle.state==NSControlStateValueOn;self.managing=YES;self.lifecycleToggle.enabled=NO;self.uninstallButton.enabled=NO;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *error=nil;BOOL success=enable?[self.management enableAutomaticLaunch:&error]:[self.management disableAutomaticLaunch:&error];dispatch_async(dispatch_get_main_queue(),^{self.managing=NO;if(success){self.feedback.textColor=NSColor.secondaryLabelColor;self.feedback.stringValue=enable?@"已启用随“邮件”自动启动。":@"已关闭自动启动。";}else [self showError:error.localizedDescription?:@"自动启动设置失败，请重试。" ];[self refresh:nil];});});
}
- (void)openSample:(id)sender {NSURL *sample=[self.management.appURL URLByAppendingPathComponent:@"Contents/Resources/layout-sample.eml"];if(![NSFileManager.defaultManager fileExistsAtPath:sample.path]||![NSWorkspace.sharedWorkspace openURL:sample])[self showError:@"示例邮件无法打开，请检查应用是否安装完整。" ];}
- (void)openReleases:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/luoshuang148/MailTrans/releases"]];}
- (void)openHelp:(id)sender {[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"https://github.com/luoshuang148/MailTrans/blob/main/docs/getting-started.zh-CN.md"]];}
- (void)confirmUninstall:(id)sender {
 if(self.managing||self.refreshing){[self showError:@"正在检查或更改状态，请稍后再卸载。" ];return;}
 NSAlert *alert=[NSAlert new];alert.alertStyle=NSAlertStyleWarning;alert.messageText=@"将 MailTrans 移到废纸篓？";
 alert.informativeText=[NSString stringWithFormat:@"请先退出“邮件”。这会关闭自动启动、注销扩展、清空翻译缓存，并将以下应用移到废纸篓：\n%@\n原邮件、附件和苹果语言包会保留。",self.management.appURL.path];
 [alert addButtonWithTitle:@"取消"];[alert addButtonWithTitle:@"移到废纸篓"];[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response){if(response!=NSAlertSecondButtonReturn)return;self.managing=YES;self.lifecycleToggle.enabled=NO;self.uninstallButton.enabled=NO;dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *error=nil;BOOL success=[self.management uninstallConfirmed:YES error:&error];dispatch_async(dispatch_get_main_queue(),^{self.managing=NO;if(success){if(self.cacheClearHandler)self.cacheClearHandler();[self.window close];if(self.quitHandler)self.quitHandler();}else{[self showError:error.localizedDescription?:@"卸载未完成，应用仍保留。" ];[self refresh:nil];}});});}];
}
@end
