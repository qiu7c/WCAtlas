#import "WCAtlasMomentsTail.h"
#import "WCAtlasEnhancements.h"
#import "WCAtlasLogging.h"
#import "WCAtlasPrivateAPI.h"
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

extern void MSHookMessageEx(Class cls, SEL selector, IMP replacement, IMP *original);

static BOOL WCAtlasMomentsTailPostSessionSet;
static NSString *WCAtlasMomentsTailPostSessionAppID;

static NSObject *WCAtlasMomentsTailStateLock(void) {
    static NSObject *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ lock = [NSObject new]; });
    return lock;
}

#pragma mark - Registered App Catalog

static NSArray<NSDictionary<NSString *, NSString *> *> *WCAtlasMomentsTailEntries(void) {
    static NSArray *entries;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Read-only extraction of WCRefine 2.1-2's hardcoded allEntries catalog.
        // Some display names are themselves wx-prefixed IDs, so extraction follows
        // the dictionary construction order rather than guessing from the string shape.
        entries = @[
            @{ @"id": @"wxda2ce55e23a3e06c", @"name": @"爱疯18k永恒钻石版" },
            @{ @"id": @"wx511c8b609d0c7710", @"name": @"来自BMW X5社交互联" },
            @{ @"id": @"wx281a70a3d390bdf2", @"name": @"好友已设置小可爱可见" },
            @{ @"id": @"wxb09d381947fc1678", @"name": @"像我这样的一个人" },
            @{ @"id": @"wxf0bcb316d289f6a4", @"name": @"亮丽内蒙古" },
            @{ @"id": @"wxe0cf858703575ebb", @"name": @"FBI专用手机" },
            @{ @"id": @"wxffee936f89cd0db9", @"name": @"来自紫霞仙子的手机" },
            @{ @"id": @"wx5fa4ebf320cf69f5", @"name": @"垃圾桶捡到的手机" },
            @{ @"id": @"wxe6f1e2780ae2a481", @"name": @"仅限长比我丑的人可见" },
            @{ @"id": @"wxaf048e83e0ab3f08", @"name": @"来自一位陌生的透明人" },
            @{ @"id": @"wx9ad15554b19159ee", @"name": @"我能对你笑便能对你哭" },
            @{ @"id": @"wx7395b7ea7ae1cab7", @"name": @"主动久了便会累了" },
            @{ @"id": @"wx77909ff94ab8b236", @"name": @"一杯敬明天一杯敬过往" },
            @{ @"id": @"wxbd1caba2e56648a2", @"name": @"来自吃鸡大神专用手机" },
            @{ @"id": @"wx3e73d1816c6e065a", @"name": @"来自天上人间钻石VIP" },
            @{ @"id": @"wx1bf866d2942d372f", @"name": @"来自穷人专用老年机" },
            @{ @"id": @"wxff725ddb21b2e1f7", @"name": @"先放手的人最心痛" },
            @{ @"id": @"wxb4adc29695b46e90", @"name": @"翻盖大哥大" },
            @{ @"id": @"wxcd3130c3a4ae2177", @"name": @"你若安好我便不扰" },
            @{ @"id": @"wxb42414c035f71567", @"name": @"来自博亿达保险专用机" },
            @{ @"id": @"wx6d9823e75d12ae61", @"name": @"上瘾的东西不会是甜的" },
            @{ @"id": @"wx8f7f888f74380733", @"name": @"By iPhone X" },
            @{ @"id": @"wxf8451614bded3112", @"name": @"iPhone XI内测机" },
            @{ @"id": @"wxcdaef18b70a86147", @"name": @"IPhone Xi Max工程机" },
            @{ @"id": @"wxa6eb9f1e291d445f", @"name": @"二狗哥哥的iPhone" },
            @{ @"id": @"wxca25444c1e5649c5", @"name": @"iPhone Xi Max工程机" },
            @{ @"id": @"wx224098d46d4e8bde", @"name": @"13888888888" },
            @{ @"id": @"wx322bb520817c18e7", @"name": @"懒癌晚期已弃疗" },
            @{ @"id": @"wx2498965842637a13", @"name": @"肉的理想白菜命" },
            @{ @"id": @"wxd80e96b5e48d7728", @"name": @"点赞有惊喜Surprise" },
            @{ @"id": @"wx142f30ba774eae62", @"name": @"森米良心小卖家" },
            @{ @"id": @"wx912d5d0260ab5965", @"name": @"付费看评论" },
            @{ @"id": @"wx5ce6035a51a71c8d", @"name": @"同时提到了你" },
            @{ @"id": @"wxe0d515767e6c3e1e", @"name": @"已关闭评论功能" },
            @{ @"id": @"wxfc6a2aae239774b5", @"name": @"王者内测专用机" },
            @{ @"id": @"wx20f9c2070f1c3156", @"name": @"需要一个件维持生活" },
            @{ @"id": @"wx3fb4f32d3930a347", @"name": @"吃鸡内测专用机" },
            @{ @"id": @"wxc061a68197db1e6a", @"name": @"你拿的住我嘛" },
            @{ @"id": @"wxb95263bc58ab28da", @"name": @"生日快乐鸭" },
            @{ @"id": @"wx4ba729b57c4859d5", @"name": @"HUAWEI P30Pro" },
            @{ @"id": @"wxd5a171b821e04a1e", @"name": @"看到请还钱" },
            @{ @"id": @"wxfcc50503e0ba579a", @"name": @"淼淼的IPhone X" },
            @{ @"id": @"wx2359940f314a69f7", @"name": @"iPhone XE" },
            @{ @"id": @"wx196da8c2beb9a80c", @"name": @"神一样的男人" },
            @{ @"id": @"wx528bc3d4b664d037", @"name": @"仇家多不方便透漏名字" },
            @{ @"id": @"wx315ce2808c20cb43", @"name": @"一直被模仿从未被超越" },
            @{ @"id": @"wx367b267970d4cff8", @"name": @"今日还钱打99折" },
            @{ @"id": @"wx1b17d828fdad34cc", @"name": @"克克克克业业" },
            @{ @"id": @"wxe299f0e6b1f956e2", @"name": @"祝自己生日快乐" },
            @{ @"id": @"wx562d2e7716c4e622", @"name": @"别放弃治疗" },
            @{ @"id": @"wxaff9498e091aa711", @"name": @"点赞后显示咋自定义" },
            @{ @"id": @"wx7c54fdba0fa911a8", @"name": @"点赞后查看详情" },
            @{ @"id": @"wxe41414ecc104b2ff", @"name": @"HUAWEI Mate40" },
            @{ @"id": @"wxd6691b857145f7f0", @"name": @"HUAWEI MateX" },
            @{ @"id": @"wxafd95c7c133d01d5", @"name": @"HUAWEI Mate30" },
            @{ @"id": @"wx8b42cb3499e1c520", @"name": @"HUAWEI P40" },
            @{ @"id": @"wx934ec697e72a2fe1", @"name": @"叙利亚打工中" },
            @{ @"id": @"wxa91fccd5ffa9b407", @"name": @"对方正在输入" },
            @{ @"id": @"wx115bcff956fd0905", @"name": @"仅限渣女可见" },
            @{ @"id": @"wx3f4266934f0e29fb", @"name": @"仅限渣男可见" },
            @{ @"id": @"wx81474f8de1253450", @"name": @"诺基亚N72" },
            @{ @"id": @"wxb537a7de758633d2", @"name": @"摩托罗拉328C" },
            @{ @"id": @"wxea2a989cebb8d5d2", @"name": @"佳能EOS1D X相机" },
            @{ @"id": @"wxe0c0578e15b5df13", @"name": @"买菜必涨价超级加倍" },
            @{ @"id": @"wx01a907ff432e7576", @"name": @"DJI御mavic2专业版" },
            @{ @"id": @"wx0a0f2bf2d182f54e", @"name": @"我是颜值主播不露脸" },
            @{ @"id": @"wxe2a19dccf56fd564", @"name": @"工商银行" },
            @{ @"id": @"wx203a1671e701a3ae", @"name": @"支付宝" },
            @{ @"id": @"wx6d7e881b87cd1114", @"name": @"LV" },
            @{ @"id": @"wxf5a0f2eb63b78447", @"name": @"保时捷" },
            @{ @"id": @"wxaadbab9d13edff20", @"name": @"快手" },
            @{ @"id": @"wxc4c0253df149f02d", @"name": @"和平精英" },
            @{ @"id": @"wx95a3a4d7c627e07d", @"name": @"王者荣耀" },
            @{ @"id": @"wxd930ea5d5a258f4f", @"name": @"openweixin Sdk" },
            @{ @"id": @"wx276cd3ba4592bb9f", @"name": @"蛋仔派对" },
            @{ @"id": @"wx45116b30f23e0cc4", @"name": @"波点音乐" },
            @{ @"id": @"wxb0eef1f67b7a2949", @"name": @"国家反诈中心" },
            @{ @"id": @"wxb45673e2d96faa6a", @"name": @"淘宝" },
            @{ @"id": @"wxa140d866ec0fe092", @"name": @"光遇" },
            @{ @"id": @"wxae34109a271f7254", @"name": @"阿里云盘" },
            @{ @"id": @"wxdf261c3b90ffbc25", @"name": @"中国电信" },
            @{ @"id": @"wx9f6523d23a33a5b3", @"name": @"美团外卖" },
            @{ @"id": @"wxf0a80d0ac2e82aa7", @"name": @"QQ" },
            @{ @"id": @"wx9ceeba6e63dd491a", @"name": @"讯飞输入法" },
            @{ @"id": @"wxb08b45996fcdb650", @"name": @"Blurrr软件" },
            @{ @"id": @"wx76fdd06dde311af3", @"name": @"抖音" },
            @{ @"id": @"wx1ebb9c41ccbfb6d4", @"name": @"肯德基" },
            @{ @"id": @"wx6d8030a2f43b09a2", @"name": @"麦当劳" },
            @{ @"id": @"wxace271fb4fda0bc2", @"name": @"麦当劳STG" },
            @{ @"id": @"wx640ea70eb695d13a", @"name": @"微店" },
            @{ @"id": @"wx967c25b040d37a06", @"name": @"皮皮虾" },
            @{ @"id": @"wx16516ad81c31d872", @"name": @"最右" },
            @{ @"id": @"wx1c37343fc2a86bc4", @"name": @"原神" },
            @{ @"id": @"wxef5e7e401d2565f7", @"name": @"QQ邮箱" },
            @{ @"id": @"wxd8a2750ce9d46980", @"name": @"小红书" },
            @{ @"id": @"wx9b913299215a38f2", @"name": @"高德地图" },
            @{ @"id": @"wx4a2015b1eba8b32c", @"name": @"Hello语音" },
            @{ @"id": @"wx2654d9155d70a468", @"name": @"中国建设银行" },
            @{ @"id": @"wx59cc372381201d39", @"name": @"瑞幸咖啡" },
            @{ @"id": @"wxbe109926790a6b4a", @"name": @"葫芦侠" },
            @{ @"id": @"wx77d53b84434b9d9a", @"name": @"拼多多" },
            @{ @"id": @"wx8b5220847f7bb64f", @"name": @"学习通" },
            @{ @"id": @"wxe75a2e68877315fb", @"name": @"京东" },
            @{ @"id": @"wxf6f9993ebaa8d663", @"name": @"钉钉" },
            @{ @"id": @"wxb84362f15c06b3f2", @"name": @"铁路12306" },
            @{ @"id": @"wx0ea99e425e26f1d4", @"name": @"交管12123" },
            @{ @"id": @"wxba9074d7f4eeae4e", @"name": @"中国移动" },
            @{ @"id": @"wxc4d74fa6f3968535", @"name": @"百度贴吧移动支付" },
            @{ @"id": @"wx77e0ce8ec8251e8d", @"name": @"贴吧公测App" },
            @{ @"id": @"wx25a5ad4ed63c2176", @"name": @"贴吧Debug" },
            @{ @"id": @"wx18f4395f7d76645a", @"name": @"大师Pro开发版" },
            @{ @"id": @"wxf510c23171aefc1a", @"name": @"大师Pro测试版" },
            @{ @"id": @"wx0aa69088a182a76e", @"name": @"大师Pro" },
            @{ @"id": @"wx3858261cdede9ca0", @"name": @"喵喵机" },
            @{ @"id": @"wx6b5d149cf4477e08", @"name": @"桌面喵" },
            @{ @"id": @"wx8d1a39cef44841a8", @"name": @"猫之城" },
            @{ @"id": @"wx5e1940228175fdc5", @"name": @"720云" },
            @{ @"id": @"wx14e6b0215602695c", @"name": @"Blued" },
            @{ @"id": @"wxc1ac68bd3d5a7381", @"name": @"CAD看图王" },
            @{ @"id": @"wxf789c03c017d58d6", @"name": @"CSDN" },
            @{ @"id": @"wx1e7c471af7c85aec", @"name": @"DJ多多" },
            @{ @"id": @"wx2362365843371394", @"name": @"DJ嗨嗨" },
            @{ @"id": @"wxbada3fc7a6cb8d22", @"name": @"IT之家" },
            @{ @"id": @"wx0d7f08b94ce109b2", @"name": @"jovi输入法" },
            @{ @"id": @"wxb282679aa5d87d4a", @"name": @"Keep" },
            @{ @"id": @"wxdb691a69fbe2a6a7", @"name": @"Max＋" },
            @{ @"id": @"wx288c5706af4794ee", @"name": @"Moon月球" },
            @{ @"id": @"wx58837a82c2e0ed15", @"name": @"QQ安全中心" },
            @{ @"id": @"wx360b06d575d20cc3", @"name": @"QQ飞车手游" },
            @{ @"id": @"wxc71c879291b0f5ec", @"name": @"QQ输入法手机版" },
            @{ @"id": @"wx1d0f5457c7556472", @"name": @"QQ小世界" },
            @{ @"id": @"wx5aa333606550dfd5", @"name": @"QQ音乐" },
            @{ @"id": @"wx5ca58eed072c774e", @"name": @"Top Widgets" },
            @{ @"id": @"wx020a535dccd46c11", @"name": @"UC浏览器" },
            @{ @"id": @"wx71955f58e7747601", @"name": @"VN视频剪辑" },
            @{ @"id": @"wxfcbcc7b981b4013c", @"name": @"WIFI万能钥匙Pro版" },
            @{ @"id": @"wx804d91d1cee20313", @"name": @"Y2002音乐" },
            @{ @"id": @"wx9ad0060a6cff3d45", @"name": @"Zepp" },
            @{ @"id": @"wx05a5c3841b61aaf8", @"name": @"ZeppLife" },
            @{ @"id": @"wx2fab8a9063c8c6d0", @"name": @"爱奇艺" },
            @{ @"id": @"wx37a067ae9226de4d", @"name": @"傲软抠图" },
            @{ @"id": @"wx3fcdd8310a136ff8", @"name": @"百度APP" },
            @{ @"id": @"wx27a43222a6bf2931", @"name": @"百度" },
            @{ @"id": @"wxb42cca62c3f838b9", @"name": @"百度输入法" },
            @{ @"id": @"wx608a35259a6f2d5f", @"name": @"百度输入法键盘" },
            @{ @"id": @"wxa278525fb9f661fd", @"name": @"百度输入法小米版" },
            @{ @"id": @"wx289a8c58bca4c71e", @"name": @"百度贴吧" },
            @{ @"id": @"wx65cffe5f882034d1", @"name": @"百度网盘" },
            @{ @"id": @"wxcb8d4298c6a09bcb", @"name": @"哔哩哔哩" },
            @{ @"id": @"wxd54bd75ad89d33a0", @"name": @"哔哩哔哩客户端" },
            @{ @"id": @"wx83b51f04d7ebb03b", @"name": @"彩云天气Pro" },
            @{ @"id": @"wxb81788a085843d31", @"name": @"超级课程表-表表" },
            @{ @"id": @"wxffc3a16e4a8e535a", @"name": @"车来了" },
            @{ @"id": @"wx58164a91f1821369", @"name": @"穿越火线-枪战王者" },
            @{ @"id": @"wx9181ed3f223e6d76", @"name": @"春晚摇一摇" },
            @{ @"id": @"wx9b1de7cd8f8deb72", @"name": @"大麦" },
            @{ @"id": @"wx8e251222d6836a60", @"name": @"大众点评" },
            @{ @"id": @"wx06a0d7e0013fd686", @"name": @"蛋仔派对hw" },
            @{ @"id": @"wx7e8eef23216bade2", @"name": @"滴滴出行" },
            @{ @"id": @"wx00868f158610b1f7", @"name": @"第五人格" },
            @{ @"id": @"wx50a3272e1669f0c0", @"name": @"订阅号助手" },
            @{ @"id": @"wx0d3cc3a6e9f20276", @"name": @"斗破苍穹：异火重燃" },
            @{ @"id": @"wx6be84d532f192698", @"name": @"斗鱼" },
            @{ @"id": @"wx0ea7a86743e8aa47", @"name": @"堆糖" },
            @{ @"id": @"wx5d4b8c07d3999007", @"name": @"多邻国" },
            @{ @"id": @"wxecf8990f4a9ea69e", @"name": @"番茄免费小说app" },
            @{ @"id": @"wxd638ead9776a3c87", @"name": @"飞凡汽车Rising Auto" },
            @{ @"id": @"wxf680c5a113e94b3f", @"name": @"工银兴农通" },
            @{ @"id": @"wxa402496b7ea7f957", @"name": @"广发银行发现精彩APP" },
            @{ @"id": @"wx84008f9992caeaf3", @"name": @"果冻宝盒" },
            @{ @"id": @"wx0e9bd96707b56471", @"name": @"哈啰APP" },
            @{ @"id": @"wx4db69980ed8f57a4", @"name": @"汉堡睡前故事" },
            @{ @"id": @"wx015c3d7da5028dee", @"name": @"和包" },
            @{ @"id": @"wx1151bdc91cda1ed2", @"name": @"虎牙直播" },
            @{ @"id": @"wx65d8aeb837088899", @"name": @"华为浏览器" },
            @{ @"id": @"wx76fc280041c16519", @"name": @"欢乐斗地主（腾讯）" },
            @{ @"id": @"wxd9c063843bafda36", @"name": @"欢太浏览器" },
            @{ @"id": @"wxdad7cff233bd33f8", @"name": @"黄油相机" },
            @{ @"id": @"wx82dd7436af5db835", @"name": @"火影忍者" },
            @{ @"id": @"wxae75e4ceb13c9df5", @"name": @"货拉拉司机端" },
            @{ @"id": @"wxf4b42938cba94b7e", @"name": @"即刻" },
            @{ @"id": @"wx6fcf65f28d6a3919", @"name": @"驾考宝典" },
            @{ @"id": @"wx83cc040b89fc9445", @"name": @"见圳" },
            @{ @"id": @"wx6ab1a4553dcb411f", @"name": @"建行生活" },
            @{ @"id": @"wx4ed5a44d6f4fdf10", @"name": @"今日头条（社交版）" },
            @{ @"id": @"wx50d801314d9eb858", @"name": @"今日头条" },
            @{ @"id": @"wxb23e82d26e8ab140", @"name": @"金铲铲之战" },
            @{ @"id": @"wxa3b3f36fcd9df06e", @"name": @"京东金融" },
            @{ @"id": @"wxb1753a8e51d9d32d", @"name": @"酷安" },
            @{ @"id": @"wx72b795aca60ad321", @"name": @"酷狗概念版" },
            @{ @"id": @"wx79f2c4418704b4f8", @"name": @"酷狗音乐" },
            @{ @"id": @"wxc305711a2a7ad71c", @"name": @"酷我音乐" },
            @{ @"id": @"wx85686879e8891882", @"name": @"夸克" },
            @{ @"id": @"wx42d6d3bdc1cb2bdc", @"name": @"快手极速版" },
            @{ @"id": @"wxf369b525a2913087", @"name": @"乐趣用品" },
            @{ @"id": @"wx912afad5fd3f8f46", @"name": @"雷速体育" },
            @{ @"id": @"wx10e2ae0624e95569", @"name": @"黎明觉醒：生机" },
            @{ @"id": @"wxe939a762f096c3b0", @"name": @"恋爱话术pro" },
            @{ @"id": @"wxee04edfc147e07d4", @"name": @"撩蜜" },
            @{ @"id": @"wx29d28524d6eaf623", @"name": @"流利说英语" },
            @{ @"id": @"wxfdab5af74990787a", @"name": @"龙之谷" },
            @{ @"id": @"wx30d7e1a70c61789d", @"name": @"埋堆堆" },
            @{ @"id": @"wx97ae91ec83768ad4", @"name": @"猫耳" },
            @{ @"id": @"wxa552e31d6839de85", @"name": @"美团" },
            @{ @"id": @"wx39f35628c5fd95d3", @"name": @"美团外卖商家" },
            @{ @"id": @"wxe6bb36187c7fa4b9", @"name": @"梦幻西游互通版" },
            @{ @"id": @"wx4cbc67ebaa25f436", @"name": @"蜜堂好物" },
            @{ @"id": @"wxc1063474755a5f24", @"name": @"磨题帮" },
            @{ @"id": @"wx124f5809f1a1bead", @"name": @"拼多多好货" },
            @{ @"id": @"wxf77e7a0d4f534650", @"name": @"拼多多商家版" },
            @{ @"id": @"wx8d063edb6f724dd9", @"name": @"平安好车主" },
            @{ @"id": @"wx608e400f36844b88", @"name": @"平安口袋E" },
            @{ @"id": @"wx4ab005521f9f1c04", @"name": @"七猫免费小说" },
            @{ @"id": @"wx4706a9fcbbca10f2", @"name": @"企业微信" },
            @{ @"id": @"wx904fb3ecf62c7dea", @"name": @"汽水音乐" },
            @{ @"id": @"wx3c77de7b9a15dc9f", @"name": @"千千音乐" },
            @{ @"id": @"wxef84982ef5634a6e", @"name": @"悄悄友朋圈" },
            @{ @"id": @"wxcaefc046890fd638", @"name": @"清风Dj" },
            @{ @"id": @"wx2ed190385c3bafeb", @"name": @"全民K歌" },
            @{ @"id": @"wx48a3b2db49e29a1b", @"name": @"三生三世十里桃花" },
            @{ @"id": @"wx8985aa576c242138", @"name": @"扫电视" },
            @{ @"id": @"wxfbc915ff7c30e335", @"name": @"扫条码" },
            @{ @"id": @"wxed08b6c4003b1fd5", @"name": @"什么值得买" },
            @{ @"id": @"wxc933ffba7d9de4dc", @"name": @"使命召唤手游" },
            @{ @"id": @"wxf7c4c8000b39008e", @"name": @"手机阿里巴巴" },
            @{ @"id": @"wx347920cf749b82a7", @"name": @"说得相机" },
            @{ @"id": @"wxd855cafb5b488002", @"name": @"搜狗输入法" },
            @{ @"id": @"wx36174d3a5f72f64a", @"name": @"腾讯地图" },
            @{ @"id": @"wxca942bbff22e0e51", @"name": @"腾讯视频" },
            @{ @"id": @"wxccac4ab14315add3", @"name": @"腾讯手机管家" },
            @{ @"id": @"wx073f4a4daff0abe8", @"name": @"腾讯新闻" },
            @{ @"id": @"wx71873ad429f369f9", @"name": @"天天军棋" },
            @{ @"id": @"wxc30efa39c0191186", @"name": @"同花顺" },
            @{ @"id": @"wxec8f618eaecadf83", @"name": @"歪麦" },
            @{ @"id": @"wx7819539d83b9dc1e", @"name": @"完美世界" },
            @{ @"id": @"wx263e2055f871aba6", @"name": @"网易新闻专业版" },
            @{ @"id": @"wx8dd6ecd81906fd84", @"name": @"网易云音乐" },
            @{ @"id": @"wx68ca4cf18bbd5838", @"name": @"威锋社区" },
            @{ @"id": @"wx299208e619de7026", @"name": @"微博" },
            @{ @"id": @"wxc2d4705bed01319d", @"name": @"微博轻享版" },
            @{ @"id": @"wx02753775b9060fec", @"name": @"微脉圈" },
            @{ @"id": @"wxce2a6f4e935b4506", @"name": @"微脉水印相机" },
            @{ @"id": @"wx6618f1cfc6c132f8", @"name": @"微信电脑版" },
            @{ @"id": @"wxab9b71ad2b90ff34", @"name": @"微信读书" },
            @{ @"id": @"wx62d9035fd4fd2059", @"name": @"微信游戏" },
            @{ @"id": @"wx786ab81fe758bec2", @"name": @"微云" },
            @{ @"id": @"wxe70cb772111a504c", @"name": @"文字emoji" },
            @{ @"id": @"wx84ef4b0064a3b863", @"name": @"我的看房日记" },
            @{ @"id": @"wxb42f1f273716d464", @"name": @"潇湘书院" },
            @{ @"id": @"wx1ba3408a50f18d5b", @"name": @"小蚕荟" },
            @{ @"id": @"wxe8989eb8b38b5c4d", @"name": @"小黑盒" },
            @{ @"id": @"wx6489dbf9e805d4e9", @"name": @"小黄历" },
            @{ @"id": @"wx20614bfdb40644b6", @"name": @"秀色秀场" },
            @{ @"id": @"wx1b4d03357ad23b00", @"name": @"妖精的尾巴：魔导少年" },
            @{ @"id": @"wx220cd3a2b03aba92", @"name": @"妖精的尾巴力量觉醒" },
            @{ @"id": @"wx2fe12a395c426fcf", @"name": @"摇一摇" },
            @{ @"id": @"wxa9ae1d63973c3798", @"name": @"遥望" },
            @{ @"id": @"wxbdc5610cc59c1631", @"name": @"一号会员店" },
            @{ @"id": @"wx123790a68951765e", @"name": @"一起来捉妖" },
            @{ @"id": @"wxff1f0c8244042666", @"name": @"壹深圳" },
            @{ @"id": @"wx6392ee2bb4d30891", @"name": @"壹言" },
            @{ @"id": @"wx5a611599efa17e78", @"name": @"英雄联盟手游" },
            @{ @"id": @"wxbda00e1f0a7e2784", @"name": @"英语趣配音" },
            @{ @"id": @"wxd695f382e6955e5a", @"name": @"影猫电影" },
            @{ @"id": @"wxf56d7d93bc226f2e", @"name": @"友邻优课" },
            @{ @"id": @"wx5c6bfdfc3d281fa9", @"name": @"有道词典" },
            @{ @"id": @"wxf10bdff91370663d", @"name": @"有道翻译官" },
            @{ @"id": @"wxf2d9346601f834ab", @"name": @"元气壁纸" },
            @{ @"id": @"wx82582d2ace426da2", @"name": @"云闪付UnionPay" },
            @{ @"id": @"wxd3f6cb54399a8489", @"name": @"知乎" },
            @{ @"id": @"wx3e388e8f02f38759", @"name": @"智行火车票" },
            @{ @"id": @"wxc55371ea66dc0e89", @"name": @"中国建设银行手机银行" },
            @{ @"id": @"wxa13d0b8c5270d1ff", @"name": @"中国联通APP" },
            @{ @"id": @"wxb6a144065b813239", @"name": @"中国农业银行" },
            @{ @"id": @"wx51d21349ff5b33a6", @"name": @"中华万年历" },
            @{ @"id": @"wx324cd70c3e181d8b", @"name": @"中银跨境GO" },
            @{ @"id": @"wx6f1a8464fa672b11", @"name": @"转转客户端" },
            @{ @"id": @"wxbe198ad3f7f0dc4c", @"name": @"子午万年历" },
        ];
    });
    return entries;
}

static NSString *WCAtlasMomentsTailNameForAppID(NSString *appID) {
    if (appID.length == 0) return nil;
    for (NSDictionary *entry in WCAtlasMomentsTailEntries()) {
        if ([entry[@"id"] isEqualToString:appID]) return entry[@"name"];
    }
    return nil;
}

static NSString *WCAtlasMomentsTailEffectiveAppID(void) {
    if (![NSUserDefaults.standardUserDefaults boolForKey:WCAtlasMomentsTailEnabledKey]) return nil;
    @synchronized (WCAtlasMomentsTailStateLock()) {
        if (WCAtlasMomentsTailPostSessionSet) return WCAtlasMomentsTailPostSessionAppID;
    }
    return [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasMomentsTailAppIDKey];
}

static NSString *WCAtlasMomentsTailPickerSelection(BOOL postSessionMode) {
    if (postSessionMode) {
        @synchronized (WCAtlasMomentsTailStateLock()) {
            if (WCAtlasMomentsTailPostSessionSet) return WCAtlasMomentsTailPostSessionAppID;
        }
    }
    return [NSUserDefaults.standardUserDefaults stringForKey:WCAtlasMomentsTailAppIDKey];
}

static void WCAtlasMomentsTailResetPostSession(void) {
    @synchronized (WCAtlasMomentsTailStateLock()) {
        WCAtlasMomentsTailPostSessionSet = NO;
        WCAtlasMomentsTailPostSessionAppID = nil;
    }
}

#pragma mark - Picker

@interface WCAtlasMomentsTailPickerViewController : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, assign) BOOL postSessionMode;
@property (nonatomic, copy) void (^completion)(void);
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *displayedEntries;
@property (nonatomic, strong) UISearchController *searchController;
- (void)applyAppID:(NSString * _Nullable)appID;
- (void)presentCustomInput;
@end

@implementation WCAtlasMomentsTailPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.postSessionMode ? @"发圈尾巴" : @"朋友圈小尾巴";
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.displayedEntries = WCAtlasMomentsTailEntries();
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索预设名称或 AppID";
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
}

- (void)done {
    if (self.navigationController.presentingViewController || self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0 || section == 2) return 1;
    return (NSInteger)self.displayedEntries.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 1 ? @"已注册 AppID 预设" : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) return @"自定义项只接受当前预设目录中已注册的 AppID，不会尝试伪造或猜测应用注册信息。";
    if (section != 1) return nil;
    return self.postSessionMode
        ? @"本次选择只影响当前这条朋友圈；选择“无小尾巴”不会修改默认设置。"
        : @"尾巴来自 WCAppInfo 的 AppID/AppName，不会修改朋友圈正文或设备型号。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tail"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tail"];
    NSString *selectedID = WCAtlasMomentsTailPickerSelection(self.postSessionMode);
    if (indexPath.section == 0) {
        cell.textLabel.text = @"无小尾巴";
        cell.detailTextLabel.text = self.postSessionMode ? @"仅本条不带来源尾巴" : @"清除默认来源尾巴";
        cell.accessoryType = selectedID.length == 0 ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else if (indexPath.section == 1) {
        NSDictionary *entry = self.displayedEntries[(NSUInteger)indexPath.row];
        cell.textLabel.text = entry[@"name"];
        cell.detailTextLabel.text = entry[@"id"];
        cell.accessoryType = [entry[@"id"] isEqualToString:selectedID]
            ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        cell.textLabel.text = @"自定义输入 AppID";
        cell.detailTextLabel.text = @"粘贴已注册的 wx… AppID";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        [self presentCustomInput];
        return;
    }
    NSString *appID = indexPath.section == 0 ? nil : self.displayedEntries[(NSUInteger)indexPath.row][@"id"];
    [self applyAppID:appID];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (query.length == 0) {
        self.displayedEntries = WCAtlasMomentsTailEntries();
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *entry, __unused NSDictionary *bindings) {
            return [entry[@"name"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound ||
                   [entry[@"id"] rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }];
        self.displayedEntries = [WCAtlasMomentsTailEntries() filteredArrayUsingPredicate:predicate];
    }
    [self.tableView reloadData];
}

- (void)applyAppID:(NSString *)appID {
    if (self.postSessionMode) {
        @synchronized (WCAtlasMomentsTailStateLock()) {
            WCAtlasMomentsTailPostSessionSet = YES;
            WCAtlasMomentsTailPostSessionAppID = [appID copy];
        }
    } else {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        if (appID.length > 0) [defaults setObject:appID forKey:WCAtlasMomentsTailAppIDKey];
        else [defaults removeObjectForKey:WCAtlasMomentsTailAppIDKey];
    }
    [self.tableView reloadData];
    if (self.completion) self.completion();
}

- (void)presentCustomInput {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"自定义 AppID"
        message:@"仅可选择预设目录中已注册的 AppID" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"wx…";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"使用" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *appID = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (WCAtlasMomentsTailNameForAppID(appID).length > 0) {
            [weakSelf applyAppID:appID];
            return;
        }
        UIAlertController *failure = [UIAlertController alertControllerWithTitle:@"未注册 AppID"
            message:@"该 AppID 不在已核验的来源应用目录中，未作修改。" preferredStyle:UIAlertControllerStyleAlert];
        [failure addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
        [weakSelf presentViewController:failure animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

UIViewController *WCAtlasMomentsTailPicker(BOOL postSession, void (^completion)(void)) {
    WCAtlasMomentsTailPickerViewController *picker = [WCAtlasMomentsTailPickerViewController new];
    picker.postSessionMode = postSession;
    picker.completion = completion;
    return picker;
}

#pragma mark - Upload Task Hook

typedef id (*WCAtlasMomentsTailObjectIMP)(id, SEL);
typedef id (*WCAtlasMomentsTailObjectObjectIMP)(id, SEL, id);
typedef id (*WCAtlasMomentsTailObjectObjectObjectIMP)(id, SEL, id, id);
typedef void (*WCAtlasMomentsTailVoidIMP)(id, SEL);
typedef void (*WCAtlasMomentsTailVoidBoolIMP)(id, SEL, BOOL);

static WCAtlasMomentsTailObjectIMP WCAtlasMomentsTailOriginalAppInfo;
static WCAtlasMomentsTailObjectIMP WCAtlasMomentsTailOriginalInit;
static WCAtlasMomentsTailObjectObjectObjectIMP WCAtlasMomentsTailOriginalInitImagesContacts;
static WCAtlasMomentsTailObjectObjectIMP WCAtlasMomentsTailOriginalInitSightDraft;
static WCAtlasMomentsTailObjectIMP WCAtlasMomentsTailOriginalInitTextType;
static WCAtlasMomentsTailVoidIMP WCAtlasMomentsTailOriginalReloadData;
static WCAtlasMomentsTailVoidBoolIMP WCAtlasMomentsTailOriginalViewDidAppear;

static id WCAtlasMomentsTailAppInfo(id self, SEL selector) {
    NSString *appID = WCAtlasMomentsTailEffectiveAppID();
    NSString *appName = WCAtlasMomentsTailNameForAppID(appID);
    id info = appID.length > 0 && appName.length > 0
        ? WCAtlasPrivateCreateMomentsAppInfo(appID, appName) : nil;
    return info ?: (WCAtlasMomentsTailOriginalAppInfo ? WCAtlasMomentsTailOriginalAppInfo(self, selector) : nil);
}

static id WCAtlasMomentsTailInit(id self, SEL selector) {
    id result = WCAtlasMomentsTailOriginalInit ? WCAtlasMomentsTailOriginalInit(self, selector) : self;
    WCAtlasMomentsTailResetPostSession();
    return result;
}

static id WCAtlasMomentsTailInitImagesContacts(id self, SEL selector, id images, id contacts) {
    id result = WCAtlasMomentsTailOriginalInitImagesContacts
        ? WCAtlasMomentsTailOriginalInitImagesContacts(self, selector, images, contacts) : self;
    WCAtlasMomentsTailResetPostSession();
    return result;
}

static id WCAtlasMomentsTailInitSightDraft(id self, SEL selector, id draft) {
    id result = WCAtlasMomentsTailOriginalInitSightDraft
        ? WCAtlasMomentsTailOriginalInitSightDraft(self, selector, draft) : self;
    WCAtlasMomentsTailResetPostSession();
    return result;
}

static id WCAtlasMomentsTailInitTextType(id self, SEL selector) {
    id result = WCAtlasMomentsTailOriginalInitTextType
        ? WCAtlasMomentsTailOriginalInitTextType(self, selector) : self;
    WCAtlasMomentsTailResetPostSession();
    return result;
}

#pragma mark - Composer Cell Injection

static NSString *WCAtlasMomentsTailRightValue(void) {
    NSString *appID = WCAtlasMomentsTailEffectiveAppID();
    return WCAtlasMomentsTailNameForAppID(appID) ?: @"无小尾巴";
}

static void WCAtlasMomentsTailInjectCell(id controller) {
    if (!WCAtlasEnhancementEnabled(WCAtlasMomentsTailEnabledKey)) return;
    WCAtlasPrivateInstallMomentsTailCell(controller,
                                      NSSelectorFromString(@"wcatlas_onMomentsTailCell"),
                                      WCAtlasMomentsTailRightValue());
}

static void WCAtlasMomentsTailOpenPicker(id self, SEL selector) {
    WCAtlasPrivateResignMomentsComposerInput(self);
    __weak id weakController = self;
    UIViewController *picker = WCAtlasMomentsTailPicker(YES, ^{
        id controller = weakController;
        WCAtlasPrivateReloadMomentsTailCell(controller, WCAtlasMomentsTailRightValue());
    });
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    [(UIViewController *)self presentViewController:navigation animated:YES completion:nil];
}

static void WCAtlasMomentsTailReloadData(id self, SEL selector) {
    if (WCAtlasMomentsTailOriginalReloadData) WCAtlasMomentsTailOriginalReloadData(self, selector);
    WCAtlasMomentsTailInjectCell(self);
}

static void WCAtlasMomentsTailViewDidAppear(id self, SEL selector, BOOL animated) {
    if (WCAtlasMomentsTailOriginalViewDidAppear) WCAtlasMomentsTailOriginalViewDidAppear(self, selector, animated);
    WCAtlasMomentsTailInjectCell(self);
}

#pragma mark - Hook Registration

static BOOL WCAtlasMomentsTailMethodMatches(Class cls, SEL selector, unsigned int arguments,
                                           char returnType, const char *explicitTypes) {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != arguments) return NO;
    char *result = method_copyReturnType(method);
    const char *resolvedResult = result;
    while (resolvedResult && *resolvedResult && strchr("rnNoORV", *resolvedResult)) resolvedResult++;
    BOOL matches = resolvedResult && resolvedResult[0] == returnType;
    if (result) free(result);
    for (unsigned int index = 2; matches && index < arguments; index++) {
        char *type = method_copyArgumentType(method, index);
        const char *resolvedType = type;
        while (resolvedType && *resolvedType && strchr("rnNoORV", *resolvedType)) resolvedType++;
        char expected = explicitTypes[index - 2];
        matches = resolvedType && (resolvedType[0] == expected ||
            (expected == 'B' && strchr("cCsSiIlLqQB", resolvedType[0]) != NULL));
        if (type) free(type);
    }
    return matches;
}

void WCAtlasMomentsTailInstallHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class uploadClass = NSClassFromString(@"WCUploadTask");
        SEL appInfoSelector = NSSelectorFromString(@"appInfo");
        if (WCAtlasMomentsTailMethodMatches(uploadClass, appInfoSelector, 2, '@', "")) {
            IMP original = NULL;
            MSHookMessageEx(uploadClass, appInfoSelector, (IMP)WCAtlasMomentsTailAppInfo, &original);
            WCAtlasMomentsTailOriginalAppInfo = (WCAtlasMomentsTailObjectIMP)original;
        }

        Class composerClass = NSClassFromString(@"WCNewCommitViewController");
        if (!composerClass) return;
        class_addMethod(composerClass, NSSelectorFromString(@"wcatlas_onMomentsTailCell"),
                        (IMP)WCAtlasMomentsTailOpenPicker, "v@:");

#define WCATLAS_HOOK_TAIL(name, args, ret, types, replacement, storage, castType) do { \
    SEL s = NSSelectorFromString(name); \
    if (WCAtlasMomentsTailMethodMatches(composerClass, s, args, ret, types)) { \
        IMP original = NULL; MSHookMessageEx(composerClass, s, (IMP)replacement, &original); \
        storage = (castType)original; \
    } \
} while (0)
        WCATLAS_HOOK_TAIL(@"init", 2, '@', "", WCAtlasMomentsTailInit,
                        WCAtlasMomentsTailOriginalInit, WCAtlasMomentsTailObjectIMP);
        WCATLAS_HOOK_TAIL(@"initWithImages:contacts:", 4, '@', "@@", WCAtlasMomentsTailInitImagesContacts,
                        WCAtlasMomentsTailOriginalInitImagesContacts, WCAtlasMomentsTailObjectObjectObjectIMP);
        WCATLAS_HOOK_TAIL(@"initWithSightDraft:", 3, '@', "@", WCAtlasMomentsTailInitSightDraft,
                        WCAtlasMomentsTailOriginalInitSightDraft, WCAtlasMomentsTailObjectObjectIMP);
        WCATLAS_HOOK_TAIL(@"initWithTextType", 2, '@', "", WCAtlasMomentsTailInitTextType,
                        WCAtlasMomentsTailOriginalInitTextType, WCAtlasMomentsTailObjectIMP);
        WCATLAS_HOOK_TAIL(@"reloadData", 2, 'v', "", WCAtlasMomentsTailReloadData,
                        WCAtlasMomentsTailOriginalReloadData, WCAtlasMomentsTailVoidIMP);
        WCATLAS_HOOK_TAIL(@"viewDidAppear:", 3, 'v', "B", WCAtlasMomentsTailViewDidAppear,
                        WCAtlasMomentsTailOriginalViewDidAppear, WCAtlasMomentsTailVoidBoolIMP);
#undef WCATLAS_HOOK_TAIL
        WCAtlasLog(@"朋友圈来源尾巴 Hook 已安装");
    });
}
