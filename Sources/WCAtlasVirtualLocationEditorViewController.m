#import "WCAtlasVirtualLocationEditorViewController.h"

#import "WCAtlasSettingsTheme.h"
#import "WCAtlasVirtualLocation.h"

typedef NS_ENUM(NSInteger, WCAtlasVirtualLocationEditorSection) {
    WCAtlasVirtualLocationEditorSectionCurrent = 0,
    WCAtlasVirtualLocationEditorSectionEntry,
    WCAtlasVirtualLocationEditorSectionSave,
    WCAtlasVirtualLocationEditorSectionPresets,
    WCAtlasVirtualLocationEditorSectionNudge,
    WCAtlasVirtualLocationEditorSectionClear,
    WCAtlasVirtualLocationEditorSectionCount,
};

typedef NS_ENUM(NSInteger, WCAtlasVirtualLocationEditorDirection) {
    WCAtlasVirtualLocationEditorDirectionNorth = 0,
    WCAtlasVirtualLocationEditorDirectionSouth,
    WCAtlasVirtualLocationEditorDirectionEast,
    WCAtlasVirtualLocationEditorDirectionWest,
};

/// One nudge step. 0.001 degrees is about 111 m of latitude, and about 95 m of
/// longitude at the latitude most users sit at.
static const double WCAtlasVirtualLocationNudgeStep = 0.001;

#pragma mark - Editor

@interface WCAtlasVirtualLocationEditorViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *latitudeField;
@property (nonatomic, strong) UITextField *longitudeField;
/// Shown once when WeChat's own picker could not be opened.
@property (nonatomic, copy, nullable) NSString *pickerNotice;
@end

@implementation WCAtlasVirtualLocationEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"手动输入定位";
    // Taken and cleared, so it is only ever shown to the user who was redirected
    // here and not again on the next visit.
    self.pickerNotice = WCAtlasVirtualLocationPickerNotice();
    if (self.pickerNotice.length > 0) WCAtlasVirtualLocationSetPickerNotice(nil);
    self.latitudeField = [self buildFieldWithPlaceholder:@"31.230416"];
    self.longitudeField = [self buildFieldWithPlaceholder:@"121.473701"];
    self.latitudeField.returnKeyType = UIReturnKeyNext;
    [self fillFieldsFromSelection];
}

- (UITextField *)buildFieldWithPlaceholder:(NSString *)placeholder {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.delegate = self;
    // Both are set explicitly: a bare UITextField draws black text, which is
    // invisible on the dark card in dark mode.
    field.font = WCAtlasSettingsValueFont(1.0);
    field.textColor = WCAtlasSettingsValueColor();
    field.adjustsFontForContentSizeCategory = YES;
    field.textAlignment = NSTextAlignmentRight;
    field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    [field addTarget:self action:@selector(fieldValueChanged) forControlEvents:UIControlEventEditingChanged];
    return field;
}

#pragma mark - State

- (void)fillFieldsFromSelection {
    if (!WCAtlasVirtualLocationHasSelection()) return;
    CLLocationCoordinate2D coordinate = WCAtlasVirtualLocationCoordinate();
    self.latitudeField.text = [NSString stringWithFormat:@"%.6f", coordinate.latitude];
    self.longitudeField.text = [NSString stringWithFormat:@"%.6f", coordinate.longitude];
}

- (BOOL)enteredCoordinate:(CLLocationCoordinate2D *)outCoordinate {
    NSString *latitudeText = [self.latitudeField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSString *longitudeText = [self.longitudeField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (latitudeText.length == 0 || longitudeText.length == 0) return NO;
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitudeText.doubleValue, longitudeText.doubleValue);
    if (!WCAtlasVirtualLocationCoordinateIsValid(coordinate)) return NO;
    if (outCoordinate) *outCoordinate = coordinate;
    return YES;
}

- (NSString *)enteredCoordinateHint {
    CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
    if ([self enteredCoordinate:&coordinate]) {
        return [NSString stringWithFormat:@"将定位到 %.6f, %.6f", coordinate.latitude, coordinate.longitude];
    }
    return @"纬度需在 -90 到 90 之间，经度需在 -180 到 180 之间，且不能同时为 0";
}

- (void)fieldValueChanged {
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:WCAtlasVirtualLocationEditorSectionSave]
                  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)notifyChange {
    [self.tableView reloadData];
    if (self.onChange) self.onChange();
}

#pragma mark - Cell building

- (UITableViewCell *)cellWithTitle:(NSString *)title
                          subtitle:(NSString *)subtitle
                             color:(UIColor *)color
                         accessory:(UIView *)accessory {
    static NSString *identifier = @"WCAtlasVirtualLocationRow";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = title;
    content.secondaryText = subtitle;
    content.textProperties.font = WCAtlasSettingsTitleFont(1.0);
    content.textProperties.adjustsFontForContentSizeCategory = YES;
    content.textProperties.numberOfLines = 0;
    content.textProperties.color = color;
    content.secondaryTextProperties.font = WCAtlasSettingsSubtitleFont(1.0);
    content.secondaryTextProperties.adjustsFontForContentSizeCategory = YES;
    content.secondaryTextProperties.numberOfLines = 0;
    content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
    content.image = nil;
    CGFloat leading = WCAtlasSettingsRowContentLeading(NO, 1.0);
    CGFloat trailing = WCAtlasSettingsScale(WCAtlasSettingsAccessoryTrailing, 1.0);
    if (accessory) {
        // Reserve the field's own width so the title never runs underneath it.
        trailing += WCAtlasSettingsValueMaxWidth + WCAtlasSettingsScale(WCAtlasSettingsAccessorySpacing, 1.0);
    }
    CGFloat vertical = WCAtlasSettingsScale(WCAtlasSettingsRowVerticalPadding, 1.0);
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(vertical, leading, vertical, trailing);
    cell.contentConfiguration = content;
    if (accessory) cell.accessoryView = accessory;
    cell.separatorInset = UIEdgeInsetsMake(0.0,
                                           WCAtlasSettingsSeparatorInsetLeading(NO, NO, 1.0),
                                           0.0,
                                           WCAtlasSettingsScale(WCAtlasSettingsAccessoryTrailing, 1.0));
    WCAtlasSettingsApplyMinimumRowHeight(cell, 1.0);
    return cell;
}

- (UITableViewCell *)fieldCellWithTitle:(NSString *)title field:(UITextField *)field {
    // Built fresh rather than dequeued: the page owns the two fields for its whole
    // lifetime, and a reused cell would otherwise still be showing the field of
    // the row it was last used for.
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
    content.text = title;
    content.textProperties.font = WCAtlasSettingsTitleFont(1.0);
    content.textProperties.adjustsFontForContentSizeCategory = YES;
    content.image = nil;
    CGFloat leading = WCAtlasSettingsRowContentLeading(NO, 1.0);
    CGFloat trailingInset = WCAtlasSettingsScale(WCAtlasSettingsAccessoryTrailing, 1.0);
    CGFloat trailing = trailingInset + WCAtlasSettingsValueMaxWidth +
                       WCAtlasSettingsScale(WCAtlasSettingsAccessorySpacing, 1.0);
    CGFloat vertical = WCAtlasSettingsScale(WCAtlasSettingsRowVerticalPadding, 1.0);
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(vertical, leading, vertical, trailing);
    cell.contentConfiguration = content;
    cell.separatorInset = UIEdgeInsetsMake(0.0,
                                           WCAtlasSettingsSeparatorInsetLeading(NO, NO, 1.0),
                                           0.0,
                                           trailingInset);
    WCAtlasSettingsApplyMinimumRowHeight(cell, 1.0);
    for (UIView *subview in cell.contentView.subviews) {
        if ([subview isKindOfClass:UITextField.class] && subview != field) [subview removeFromSuperview];
    }
    [field removeFromSuperview];
    [cell.contentView addSubview:field];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [field.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [field.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-trailingInset],
        [field.widthAnchor constraintEqualToConstant:WCAtlasSettingsValueMaxWidth],
    ]];
    return cell;
}

#pragma mark - Table data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return WCAtlasVirtualLocationEditorSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case WCAtlasVirtualLocationEditorSectionEntry: return 2;
        case WCAtlasVirtualLocationEditorSectionPresets: return WCAtlasVirtualLocationPresets().count + 1;
        case WCAtlasVirtualLocationEditorSectionNudge: return 4;
        default: return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case WCAtlasVirtualLocationEditorSectionCurrent: return @"当前定位";
        case WCAtlasVirtualLocationEditorSectionEntry: return @"手动输入";
        case WCAtlasVirtualLocationEditorSectionSave: return @"保存";
        case WCAtlasVirtualLocationEditorSectionPresets: return @"收藏的地点";
        case WCAtlasVirtualLocationEditorSectionNudge: return @"微调";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case WCAtlasVirtualLocationEditorSectionEntry:
            return self.pickerNotice.length > 0 ? self.pickerNotice : @"纬度为负表示南纬，经度为负表示西经。";
        case WCAtlasVirtualLocationEditorSectionPresets:
            return WCAtlasVirtualLocationPresets().count > 0 ? @"左滑可删除收藏的地点。" : @"收藏常用坐标，之后可一键切换。";
        case WCAtlasVirtualLocationEditorSectionNudge:
            return @"每次调整 0.001°：纬度约 111 米，经度在中纬度地区约 95 米。";
        default:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case WCAtlasVirtualLocationEditorSectionCurrent: {
            UITableViewCell *cell = [self cellWithTitle:@"当前定位"
                                              subtitle:WCAtlasVirtualLocationSummary()
                                                 color:UIColor.labelColor
                                             accessory:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        case WCAtlasVirtualLocationEditorSectionEntry: {
            BOOL latitude = indexPath.row == 0;
            return [self fieldCellWithTitle:(latitude ? @"纬度" : @"经度")
                                      field:(latitude ? self.latitudeField : self.longitudeField)];
        }
        case WCAtlasVirtualLocationEditorSectionSave: {
            CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
            BOOL valid = [self enteredCoordinate:&coordinate];
            UITableViewCell *cell = [self cellWithTitle:@"应用此坐标"
                                              subtitle:[self enteredCoordinateHint]
                                                 color:(valid ? WCAtlasSettingsAccentColor() : UIColor.secondaryLabelColor)
                                             accessory:nil];
            cell.selectionStyle = valid ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
            return cell;
        }
        case WCAtlasVirtualLocationEditorSectionPresets: {
            NSArray<NSDictionary<NSString *, id> *> *presets = WCAtlasVirtualLocationPresets();
            if ((NSUInteger)indexPath.row >= presets.count) {
                return [self cellWithTitle:@"把当前坐标存为收藏"
                                  subtitle:WCAtlasVirtualLocationHasSelection() ? WCAtlasVirtualLocationCoordinateText() : @"需要先有一个坐标"
                                     color:WCAtlasVirtualLocationHasSelection() ? WCAtlasSettingsAccentColor() : UIColor.secondaryLabelColor
                                 accessory:nil];
            }
            NSDictionary<NSString *, id> *preset = presets[indexPath.row];
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([preset[@"latitude"] doubleValue],
                                                                          [preset[@"longitude"] doubleValue]);
            NSString *name = [preset[@"name"] isKindOfClass:NSString.class] ? preset[@"name"] : @"收藏";
            return [self cellWithTitle:name
                              subtitle:[NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude]
                                 color:UIColor.labelColor
                             accessory:nil];
        }
        case WCAtlasVirtualLocationEditorSectionNudge: {
            NSArray<NSString *> *titles = @[@"向北", @"向南", @"向东", @"向西"];
            BOOL enabled = WCAtlasVirtualLocationHasSelection();
            return [self cellWithTitle:titles[indexPath.row]
                              subtitle:@"0.001°"
                                 color:(enabled ? UIColor.labelColor : UIColor.secondaryLabelColor)
                             accessory:nil];
        }
        default: {
            BOOL enabled = WCAtlasVirtualLocationHasSelection();
            return [self cellWithTitle:@"清除定位"
                              subtitle:(enabled ? @"回到真实定位" : @"当前没有设置定位")
                                 color:(enabled ? UIColor.systemRedColor : UIColor.secondaryLabelColor)
                             accessory:nil];
        }
    }
}

#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.view endEditing:YES];
    switch (indexPath.section) {
        case WCAtlasVirtualLocationEditorSectionSave:
            [self applyEnteredCoordinate];
            break;
        case WCAtlasVirtualLocationEditorSectionPresets:
            [self handlePresetRow:indexPath.row];
            break;
        case WCAtlasVirtualLocationEditorSectionNudge:
            [self applyNudgeForDirection:(WCAtlasVirtualLocationEditorDirection)indexPath.row];
            break;
        case WCAtlasVirtualLocationEditorSectionClear:
            [self confirmClear];
            break;
        default:
            break;
    }
}

- (void)applyEnteredCoordinate {
    CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
    if (![self enteredCoordinate:&coordinate]) return;
    WCAtlasVirtualLocationSetCoordinate(coordinate, nil);
    [self notifyChange];
}

- (void)handlePresetRow:(NSInteger)row {
    NSArray<NSDictionary<NSString *, id> *> *presets = WCAtlasVirtualLocationPresets();
    if ((NSUInteger)row >= presets.count) {
        [self promptForPresetName];
        return;
    }
    NSDictionary<NSString *, id> *preset = presets[row];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([preset[@"latitude"] doubleValue],
                                                                  [preset[@"longitude"] doubleValue]);
    NSString *name = [preset[@"name"] isKindOfClass:NSString.class] ? preset[@"name"] : nil;
    WCAtlasVirtualLocationSetCoordinate(coordinate, name);
    [self fillFieldsFromSelection];
    [self notifyChange];
}

- (void)promptForPresetName {
    if (!WCAtlasVirtualLocationHasSelection()) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"收藏此坐标"
                                                                  message:WCAtlasVirtualLocationCoordinateText()
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"名称，例如：公司";
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        WCAtlasVirtualLocationAddPreset(name.length > 0 ? name : WCAtlasVirtualLocationCoordinateText(),
                                        WCAtlasVirtualLocationCoordinate());
        [weakSelf notifyChange];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyNudgeForDirection:(WCAtlasVirtualLocationEditorDirection)direction {
    switch (direction) {
        case WCAtlasVirtualLocationEditorDirectionNorth: WCAtlasVirtualLocationNudge(WCAtlasVirtualLocationNudgeStep, 0.0); break;
        case WCAtlasVirtualLocationEditorDirectionSouth: WCAtlasVirtualLocationNudge(-WCAtlasVirtualLocationNudgeStep, 0.0); break;
        case WCAtlasVirtualLocationEditorDirectionEast: WCAtlasVirtualLocationNudge(0.0, WCAtlasVirtualLocationNudgeStep); break;
        case WCAtlasVirtualLocationEditorDirectionWest: WCAtlasVirtualLocationNudge(0.0, -WCAtlasVirtualLocationNudgeStep); break;
    }
    [self fillFieldsFromSelection];
    [self notifyChange];
}

- (void)confirmClear {
    if (!WCAtlasVirtualLocationHasSelection()) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清除定位"
                                                                  message:@"清除后立即恢复真实定位。"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        WCAtlasVirtualLocationClear();
        weakSelf.latitudeField.text = nil;
        weakSelf.longitudeField.text = nil;
        [weakSelf notifyChange];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != WCAtlasVirtualLocationEditorSectionPresets) return nil;
    if ((NSUInteger)indexPath.row >= WCAtlasVirtualLocationPresets().count) return nil;
    __weak typeof(self) weakSelf = self;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                         title:@"删除"
                                                                       handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        WCAtlasVirtualLocationRemovePresetAtIndex((NSUInteger)indexPath.row);
        [weakSelf notifyChange];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.latitudeField) {
        [self.longitudeField becomeFirstResponder];
        return NO;
    }
    [textField resignFirstResponder];
    [self applyEnteredCoordinate];
    return NO;
}

@end