#import "PlaylistTransition.h"
#import "Core/SGCore.h"
#import "Core/SGGlass.h"
#import "Shared/CustomMix/SGCustomMixModel.h"
#import "Shared/CustomMix/SGCustomMixStore.h"

@interface SGCustomMixTransitionEditorVC : UITableViewController
@property (nonatomic, copy) NSString *fromURI;
@property (nonatomic, copy) NSString *toURI;
@property (nonatomic, copy) NSString *contextURI;
@property (nonatomic, copy) NSString *fromName;
@property (nonatomic, copy) NSString *toName;
@property (nonatomic, strong) SGCustomMixRule *rule;
@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) UISegmentedControl *triggerMode;
@property (nonatomic, strong) UISlider *triggerSlider;
@property (nonatomic, strong) UISlider *durationSlider;
@property (nonatomic, strong) UILabel *triggerValueLabel;
@property (nonatomic, strong) UILabel *durationValueLabel;
@end

@implementation SGCustomMixTransitionEditorVC

- (instancetype)initWithFromURI:(NSString *)fromURI fromName:(NSString *)fromName toURI:(NSString *)toURI toName:(NSString *)toName contextURI:(NSString *)contextURI {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _fromURI = [fromURI copy];
        _toURI = [toURI copy];
        _contextURI = [contextURI copy];
        _fromName = [fromName copy] ?: fromURI.copy;
        _toName = [toName copy] ?: toURI.copy;
        SGCustomMixRule *existing = [[SGCustomMixStore shared] ruleForFromURI:fromURI toURI:toURI contextURI:contextURI];
        _rule = existing ? [existing copy] : [SGCustomMixRule defaultRule];
        _rule.fromURI = fromURI;
        _rule.toURI = toURI;
        _rule.contextURI = contextURI;
        if (!existing) _rule.enabled = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Transition Point";
    self.view.backgroundColor = UIColor.clearColor;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)];

    _enabledSwitch = [UISwitch new];
    _enabledSwitch.on = _rule.enabled;
    [_enabledSwitch addTarget:self action:@selector(enabledChanged) forControlEvents:UIControlEventValueChanged];

    _triggerMode = [[UISegmentedControl alloc] initWithItems:@[@"End", @"Seconds", @"Percent"]];
    _triggerMode.selectedSegmentIndex = (NSInteger)_rule.triggerMode;
    [_triggerMode addTarget:self action:@selector(triggerModeChanged) forControlEvents:UIControlEventValueChanged];

    _triggerSlider = [UISlider new];
    _triggerSlider.minimumValue = 0;
    _triggerSlider.maximumValue = 100;
    [_triggerSlider addTarget:self action:@selector(triggerSliderChanged) forControlEvents:UIControlEventValueChanged];

    _durationSlider = [UISlider new];
    _durationSlider.minimumValue = 1.0;
    _durationSlider.maximumValue = 30.0;
    _durationSlider.value = (float)_rule.durationSeconds;
    [_durationSlider addTarget:self action:@selector(durationSliderChanged) forControlEvents:UIControlEventValueChanged];

    _triggerValueLabel = [UILabel new];
    _triggerValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    _triggerValueLabel.textColor = UIColor.secondaryLabelColor;
    _triggerValueLabel.textAlignment = NSTextAlignmentRight;

    _durationValueLabel = [UILabel new];
    _durationValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
    _durationValueLabel.textColor = UIColor.secondaryLabelColor;
    _durationValueLabel.textAlignment = NSTextAlignmentRight;

    [self syncTriggerUI];
    [self updateLabels];
}

- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)save {
    _rule.enabled = _enabledSwitch.isOn;
    _rule.triggerMode = (SGCustomMixTriggerMode)_triggerMode.selectedSegmentIndex;
    _rule.durationSeconds = _durationSlider.value;
    if (_rule.triggerMode == SGCustomMixTriggerSeconds) _rule.triggerValue = _triggerSlider.value;
    else if (_rule.triggerMode == SGCustomMixTriggerPercent) _rule.triggerValue = _triggerSlider.value;
    else _rule.triggerValue = 0;
    [[SGCustomMixStore shared] upsertRule:_rule forFromURI:_fromURI toURI:_toURI contextURI:_contextURI];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)enabledChanged {
    _rule.enabled = _enabledSwitch.isOn;
    [self.tableView reloadData];
}

- (void)triggerModeChanged {
    _rule.triggerMode = (SGCustomMixTriggerMode)_triggerMode.selectedSegmentIndex;
    [self syncTriggerUI];
    [self updateLabels];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)syncTriggerUI {
    if (_rule.triggerMode == SGCustomMixTriggerSeconds) {
        _triggerSlider.minimumValue = 0;
        _triggerSlider.maximumValue = 600;
        _triggerSlider.value = (float)fmin(fmax(_rule.triggerValue, 0), 600);
    } else if (_rule.triggerMode == SGCustomMixTriggerPercent) {
        _triggerSlider.minimumValue = 0;
        _triggerSlider.maximumValue = 100;
        _triggerSlider.value = (float)fmin(fmax(_rule.triggerValue, 0), 100);
    }
}

- (void)triggerSliderChanged {
    _rule.triggerValue = _triggerSlider.value;
    [self updateLabels];
}

- (void)durationSliderChanged {
    _rule.durationSeconds = _durationSlider.value;
    [self updateLabels];
}

- (void)updateLabels {
    if (_rule.triggerMode == SGCustomMixTriggerSeconds) {
        int total = (int)round(_triggerSlider.value);
        _triggerValueLabel.text = [NSString stringWithFormat:@"%d:%02d", total / 60, total % 60];
    } else if (_rule.triggerMode == SGCustomMixTriggerPercent) {
        _triggerValueLabel.text = [NSString stringWithFormat:@"%.0f%%", _triggerSlider.value];
    } else {
        _triggerValueLabel.text = @"End of song";
    }
    _durationValueLabel.text = [NSString stringWithFormat:@"%.1f s", _durationSlider.value];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return _rule.triggerMode == SGCustomMixTriggerEnd ? 1 : 2;
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Track pair";
    if (section == 1) return @"When transition starts";
    return @"Transition";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) return @"Custom Mix applies a local FX envelope and can advance to the next track at the selected point.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = [UIColor colorWithWhite:1 alpha:0.04];
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Enabled";
            cell.accessoryView = _enabledSwitch;
        } else {
            cell.textLabel.text = @"Pair";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ -> %@", _fromName ?: _fromURI, _toName ?: _toURI];
            cell.detailTextLabel.numberOfLines = 2;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Start";
            _triggerMode.frame = CGRectMake(0, 0, 220, 32);
            cell.accessoryView = _triggerMode;
        } else {
            cell.textLabel.text = _rule.triggerMode == SGCustomMixTriggerSeconds ? @"Time" : @"Percent";
            [cell.contentView addSubview:_triggerSlider];
            [cell.contentView addSubview:_triggerValueLabel];
            _triggerSlider.translatesAutoresizingMaskIntoConstraints = NO;
            _triggerValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[
                [_triggerValueLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
                [_triggerValueLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [_triggerValueLabel.widthAnchor constraintEqualToConstant:64],
                [_triggerSlider.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:120],
                [_triggerSlider.trailingAnchor constraintEqualToAnchor:_triggerValueLabel.leadingAnchor constant:-8],
                [_triggerSlider.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            ]];
        }
    } else {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Duration";
            [cell.contentView addSubview:_durationSlider];
            [cell.contentView addSubview:_durationValueLabel];
            _durationSlider.translatesAutoresizingMaskIntoConstraints = NO;
            _durationValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[
                [_durationValueLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
                [_durationValueLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [_durationValueLabel.widthAnchor constraintEqualToConstant:64],
                [_durationSlider.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:120],
                [_durationSlider.trailingAnchor constraintEqualToAnchor:_durationValueLabel.leadingAnchor constant:-8],
                [_durationSlider.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            ]];
        } else {
            cell.textLabel.text = @"Remove rule";
            cell.textLabel.textColor = UIColor.systemRedColor;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2 && indexPath.row == 1) {
        [[SGCustomMixStore shared] removeRuleForFromURI:_fromURI toURI:_toURI contextURI:_contextURI];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end

BOOL SGCustomMixPlaylistTransitionEnabled(void) {
    return SGFlag(SGKeyCustomMix, NO);
}

UIViewController *SGCustomMixTransitionEditor(NSString *fromURI, NSString *fromName, NSString *toURI, NSString *toName, NSString *contextURI) {
    if (!fromURI.length || !toURI.length) return nil;
    SGCustomMixTransitionEditorVC *vc = [[SGCustomMixTransitionEditorVC alloc] initWithFromURI:fromURI fromName:fromName toURI:toURI toName:toName contextURI:contextURI];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        if ([nav.sheetPresentationController respondsToSelector:@selector(setDetents:)]) {
            nav.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
            nav.sheetPresentationController.prefersGrabberVisible = YES;
        }
    }
    SGPresentDark(nav);
    return nav;
}

void SGCustomMixPresentTransitionEditor(UIView *sourceView, NSString *fromURI, NSString *fromName, NSString *toURI, NSString *toName, NSString *contextURI) {
    UIViewController *nav = SGCustomMixTransitionEditor(fromURI, fromName, toURI, toName, contextURI);
    if (!nav) return;
    UIViewController *presenter = sourceView.window.rootViewController;
    while (presenter.presentedViewController) presenter = presenter.presentedViewController;
    [presenter presentViewController:nav animated:YES completion:nil];
}