//
//  IAPHunterTweak.m
//  In-App StoreKit Deep Hidden Offer & Introductory Price Scanner (.dylib)
//  Quét sâu Mach-O Binary + StoreKit SKProductsRequest để tìm gói GIẢM KỲ ĐẦU & ẨN
//  và gọi trực tiếp SKPaymentQueue bật bảng App Store (FaceID) ngay trong App đích!
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>

@interface IAPHunterOverlayController : UIViewController <SKProductsRequestDelegate, SKPaymentTransactionObserver, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSMutableArray<SKProduct *> *discoveredProducts;
@property (nonatomic, strong) NSMutableSet<NSString *> *probedSKUs;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIWindow *floatingWindow;
@property (nonatomic, strong) UIButton *floatingButton;
@end

static IAPHunterOverlayController *sharedHunter = nil;

@implementation IAPHunterOverlayController

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        sharedHunter = [[IAPHunterOverlayController alloc] init];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:sharedHunter];
        [sharedHunter setupFloatingButton];
    });
}

- (void)setupFloatingButton {
    UIWindowScene *activeScene = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
            activeScene = (UIWindowScene *)scene;
            break;
        }
    }

    UIWindow *keyWindow = activeScene ? activeScene.windows.firstObject : [UIApplication sharedApplication].windows.firstObject;
    if (!keyWindow) return;

    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(keyWindow.bounds.size.width - 118, 110, 106, 38);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.92];
    self.floatingButton.layer.cornerRadius = 19;
    self.floatingButton.layer.borderWidth = 1.2;
    self.floatingButton.layer.borderColor = [UIColor colorWithRed:0.35 green:0.34 blue:0.84 alpha:0.9].CGColor;
    [self.floatingButton setTitle:@"⚡ IAP Ẩn" forState:UIControlStateNormal];
    self.floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.floatingButton setTitleColor:[UIColor colorWithRed:0.19 green:0.82 blue:0.35 alpha:1.0] forState:UIControlStateNormal];
    [self.floatingButton addTarget:self action:@selector(openScannerModal) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [self.floatingButton addGestureRecognizer:pan];

    [keyWindow addSubview:self.floatingButton];
}

- (void)handleDrag:(UIPanGestureRecognizer *)pan {
    UIView *btn = pan.view;
    CGPoint translation = [pan translationInView:btn.superview];
    btn.center = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:btn.superview];
}

- (void)openScannerModal {
    UIWindow *keyWindow = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [rootVC presentViewController:nav animated:YES completion:^{
        [self startDeepScan];
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0];
    self.title = @"Xác nhận mua & Quét IAP Ẩn";
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeModal)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Quét lại" style:UIBarButtonItemStylePlain target:self action:@selector(startDeepScan)];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, self.view.bounds.size.width - 32, 40)];
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.62 blue:0.04 alpha:1.0];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = @"🔍 Đang đào sâu Mach-O Binary & StoreKit để tìm gói GIẢM KỲ ĐẦU / ẨN...";

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableHeaderView = self.statusLabel;
    [self.view addSubview:self.tableView];
}

- (void)closeModal {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// Đào sâu vào Mach-O __TEXT,__cstring + Bundle Plist/JSON + tổ hợp SKU ẩn
- (NSSet<NSString *> *)extractDeepCandidateSKUs {
    NSMutableSet<NSString *> *candidates = [NSMutableSet set];
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.app";

    // 1. Sinh tổ hợp SKU phổ biến theo Bundle ID & các hệ sinh thái lớn (Google Gemini, Google One, CapCut, Claude, ChatGPT, Duolingo...)
    NSArray *prefixes = @[
        bundleId,
        @"com.google.gemini",
        @"com.google.one",
        @"com.google.one.ai",
        @"com.lemon.lvoverseas",
        @"com.anthropic.claude",
        @"com.openai.chat",
        @"com.duolingo.super"
    ];
    NSArray *tiers = @[
        @"ai.ultra.30tb", @"ai.ultra.20tb", @"ai.pro.5tb", @"ai.pro.2tb", @"ai.plus.400gb", @"ai.plus.2tb",
        @"ultra.30tb", @"ultra.20tb", @"pro.5tb", @"plus.400gb",
        @"pro", @"standard", @"plus", @"max.5x", @"max.20x", @"ultra", @"super", @"family", @"gold", @"platinum"
    ];
    NSArray *periods = @[
        @"monthly", @"yearly", @"annual", @"1month", @"3month", @"1year", @"12month",
        @"monthly.intro", @"monthly.intro3m", @"yearly.intro", @"yearly.promo", @"yearly.v1", @"yearly.tier2"
    ];

    for (NSString *p in prefixes) {
        for (NSString *t in tiers) {
            [candidates addObject:[NSString stringWithFormat:@"%@.%@", p, t]];
            for (NSString *per in periods) {
                [candidates addObject:[NSString stringWithFormat:@"%@.%@.%@", p, t, per]];
                [candidates addObject:[NSString stringWithFormat:@"%@_%@_%@", p, t, per]];
            }
        }
    }

    // 2. Quét toàn bộ chuỗi trong Mach-O __TEXT,__cstring của App đích để bắt các productIdentifier ẩn cứng trong Binary
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < MIN(imageCount, 12); i++) {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!header || header->magic != MH_MAGIC_64) continue;
        unsigned long size = 0;
        const char *cstrings = (const char *)getsectiondata(header, "__TEXT", "__cstring", &size);
        if (!cstrings || size == 0) continue;

        const char *ptr = cstrings;
        const char *end = cstrings + size;
        while (ptr < end) {
            size_t len = strnlen(ptr, end - ptr);
            if (len >= 8 && len <= 96) {
                NSString *str = [[NSString alloc] initWithBytes:ptr length:len encoding:NSASCIIStringEncoding];
                if (str && ([str containsString:@"."] || [str containsString:@"_"])) {
                    NSString *lower = [str lowercaseString];
                    if ([lower containsString:@"month"] || [lower containsString:@"year"] ||
                        [lower containsString:@"annual"] || [lower containsString:@"ultra"] ||
                        [lower containsString:@"pro"] || [lower containsString:@"plus"] ||
                        [lower containsString:@"sub"] || [lower containsString:@"tier"] ||
                        [lower containsString:@"tb"] || [lower containsString:@"intro"] ||
                        [lower hasPrefix:[bundleId lowercaseString]]) {
                        if (![str containsString:@" "] && ![str containsString:@"/"] && ![str containsString:@":"]) {
                            [candidates addObject:str];
                        }
                    }
                }
            }
            ptr += len + 1;
        }
    }

    return candidates;
}

- (void)startDeepScan {
    self.discoveredProducts = [NSMutableArray array];
    NSSet<NSString *> *skus = [self extractDeepCandidateSKUs];
    self.statusLabel.text = [NSString stringWithFormat:@"⏳ Đang truy vấn StoreKit cho %lu mã SKU ẩn trong Binary...", (unsigned long)skus.count];

    SKProductsRequest *req = [[SKProductsRequest alloc] initWithProductIdentifiers:skus];
    req.delegate = self;
    [req start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.discoveredProducts removeAllObjects];
        [self.discoveredProducts addObjectsFromArray:response.products];

        // Ưu tiên xếp các gói có GIẢM KỲ ĐẦU (introductoryPrice) lên đầu
        [self.discoveredProducts sortUsingComparator:^NSComparisonResult(SKProduct *a, SKProduct *b) {
            BOOL aIntro = (a.introductoryPrice != nil);
            BOOL bIntro = (b.introductoryPrice != nil);
            if (aIntro != bIntro) return aIntro ? NSOrderedAscending : NSOrderedDescending;
            return [a.price compare:b.price];
        }];

        self.statusLabel.text = [NSString stringWithFormat:@"✅ Phát hiện %lu gói StoreKit (Chạm vào gói để bật bảng App Store FaceID ngay lập tức!)", (unsigned long)self.discoveredProducts.count];
        [self.tableView reloadData];
    });
}

- (NSString *)formatPrice:(NSDecimalNumber *)price locale:(NSLocale *)locale {
    if (!price) return @"";
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.numberStyle = NSNumberFormatterCurrencyStyle;
    fmt.locale = locale ?: [NSLocale currentLocale];
    return [fmt stringFromNumber:price] ?: [price stringValue];
}

#pragma mark - TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.discoveredProducts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IAPCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"IAPCell"];
        cell.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.15 alpha:1.0];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.detailTextLabel.numberOfLines = 3;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    }

    SKProduct *prod = self.discoveredProducts[indexPath.row];
    NSString *stdPrice = [self formatPrice:prod.price locale:prod.priceLocale];

    if (prod.introductoryPrice) {
        NSString *introStr = [self formatPrice:prod.introductoryPrice.price locale:prod.priceLocale];
        NSUInteger periods = prod.introductoryPrice.numberOfPeriods;
        cell.textLabel.text = [NSString stringWithFormat:@"🔥 %@ [GIẢM KỲ ĐẦU • ẨN]", prod.localizedTitle ?: prod.productIdentifier];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.19 green:0.82 blue:0.35 alpha:1.0];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@/kỳ (Ưu đãi %lu kỳ đầu) → Sau đó %@\nSKU: %@",
                                     introStr, (unsigned long)periods, stdPrice, prod.productIdentifier];
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"🕵️ %@ [ẨN]", prod.localizedTitle ?: prod.productIdentifier];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.65 green:0.65 blue:0.70 alpha:1.0];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Giá: %@\nSKU: %@", stdPrice, prod.productIdentifier];
    }

    return cell;
}

// Khi bấm vào bất kỳ gói nào -> Mở màn hình "Xác nhận mua" và gọi thẳng SKPaymentQueue bật bảng App Store (FaceID) đè lên trên!
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SKProduct *prod = self.discoveredProducts[indexPath.row];
    if (!prod) return;

    SKPayment *payment = [SKPayment paymentWithProduct:prod];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

// Hỗ trợ ép gọi thẳng bảng App Store bằng chuỗi SKU (productIdentifier) bất kỳ qua Objective-C Runtime
- (void)forceTriggerPaymentForSKU:(NSString *)skuId {
    if (!skuId || skuId.length == 0) return;
    SEL sel = NSSelectorFromString(@"paymentWithProductIdentifier:");
    if ([SKPayment respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SKPayment *rawPayment = [SKPayment performSelector:sel withObject:skuId];
#pragma clang diagnostic pop
        if (rawPayment) {
            [[SKPaymentQueue defaultQueue] addPayment:rawPayment];
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    // Không can thiệp vào luồng xử lý biên lai gốc của App đích
}

@end
