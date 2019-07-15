//
//  RCDSelectContactViewController.m
//  SealTalk
//
//  Created by 孙浩 on 2019/6/19.
//  Copyright © 2019 RongCloud. All rights reserved.
//

#import "RCDSelectContactViewController.h"
#import "RCDTableView.h"
#import "RCDForwardManager.h"
#import <Masonry/Masonry.h>
#import "RCDUIBarButtonItem.h"
#import "RCDUtilities.h"
#import "RCDRCIMDataSource.h"
#import "RCDUserInfoManager.h"
#import "RCDForwardSelectedCell.h"
#import "RCDRightArrowCell.h"
#import "RCDBottomResultView.h"
#import "RCDHaveSelectedViewController.h"
#import "RCDSelectGroupViewController.h"

static NSString *rightArrowCellIdentifier = @"RCDRightArrowCellIdentifier";
static NSString *forwardSelectedCellIdentifier = @"RCDForwardSelectedCellIdentifier";

@interface RCDSelectContactViewController ()<UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchControllerDelegate>

@property (nonatomic, strong) RCDTableView *tableView;
@property (nonatomic, strong) UISearchBar *searchFriendsBar;

@property (nonatomic, strong) NSArray *allFriendArray;
@property (nonatomic, strong) NSArray *resultKeys;
@property (nonatomic, strong) NSDictionary *resultSectionDict;
@property (nonatomic, strong) NSMutableArray *matchFriendList;

@property (nonatomic, assign) BOOL hasSyncFriendList;
@property (nonatomic, assign) BOOL isBeginSearch;
@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, strong) RCDBottomResultView *bottomResultView;

@end

@implementation RCDSelectContactViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
    [self initData];
    [self addObserver];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavi];
    [self.searchFriendsBar resignFirstResponder];
    [self sortAndRefreshWithList:[self getAllFriendList]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UITableViewDelegate & UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows = 0;
    if (section == 0) {
        if (self.isBeginSearch == YES) {
            rows = 0;
        } else {
            rows = 1;
        }
    } else {
        NSString *letter = self.resultKeys[section - 1];
        rows = [self.resultSectionDict[letter] count];
    }
    return rows;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.resultKeys.count + 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 0;
    }
    return 21.f;
}

//如果没有该方法，tableView会默认显示footerView，其高度与headerView等高
//另外如果return 0或者0.0f是没有效果的
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.1f;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.frame = CGRectMake(0, 0, self.view.frame.size.width, 21);
    view.backgroundColor = [UIColor clearColor];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.frame = CGRectMake(13, 3, 15, 15);
    title.font = [UIFont systemFontOfSize:15.f];
    title.textColor = HEXCOLOR(0x999999);
    [view addSubview:title];
    
    if (section == 0) {
        title.text = nil;
    } else {
        title.text = self.resultKeys[section - 1];
    }
    return view;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        RCDRightArrowCell *cell = [self.tableView dequeueReusableCellWithIdentifier:rightArrowCellIdentifier];
        if (cell == nil) {
            cell = [[RCDRightArrowCell alloc] init];
        }
        [cell setLeftText:RCDLocalizedString(@"SelectGroup")];
        return cell;
    } else {
        RCDForwardSelectedCell *cell = [self.tableView dequeueReusableCellWithIdentifier:forwardSelectedCellIdentifier];
        if (cell == nil) {
            cell = [[RCDForwardSelectedCell alloc] init];
        }
        
        NSString *letter = self.resultKeys[indexPath.section - 1];
        NSArray *sectionUserInfoList = self.resultSectionDict[letter];
        RCDFriendInfo *userInfo = sectionUserInfoList[indexPath.row];
        if (userInfo) {
            [cell setFriendInfo:userInfo];
        }
        cell.selectStatus = RCDForwardSelectedStatusMultiUnSelected;
        if ([[RCDForwardManager sharedInstance] modelIsContains:userInfo.userId]) {
            cell.selectStatus = RCDForwardSelectedStatusMultiSelected;
        }
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.resultKeys;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        RCDSelectGroupViewController *selectGroupVC = [[RCDSelectGroupViewController alloc] init];
        [self.navigationController pushViewController:selectGroupVC animated:YES];
    } else {
        NSString *letter = self.resultKeys[indexPath.section - 1];
        NSArray *sectionUserInfoList = self.resultSectionDict[letter];
        RCDFriendInfo *friend = sectionUserInfoList[indexPath.row];
        if (friend == nil) {
            return;
        }
        RCDForwardSelectedCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        RCDForwardCellModel *forwardCellmodel = [[RCDForwardCellModel alloc] init];
        forwardCellmodel.targetId = friend.userId;
        forwardCellmodel.conversationType = ConversationType_PRIVATE;
        
        if (cell.selectStatus == RCDForwardSelectedStatusMultiUnSelected) {
            [[RCDForwardManager sharedInstance] addForwardModel:forwardCellmodel];
            cell.selectStatus = RCDForwardSelectedStatusMultiSelected;
        } else {
            [[RCDForwardManager sharedInstance] removeForwardModel:forwardCellmodel];
            cell.selectStatus = RCDForwardSelectedStatusMultiUnSelected;
        }
        [self updateSelectedResult];
    }
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.searchFriendsBar resignFirstResponder];
}

#pragma mark - UISearchBarDelegate
//  执行 delegate 搜索好友
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self.matchFriendList removeAllObjects];
    if (searchText.length <= 0) {
        [self sortAndRefreshWithList:self.allFriendArray];
    } else {
        for (RCDFriendInfo *userInfo in self.allFriendArray) {
            NSString *name = userInfo.name;
            if ([userInfo isKindOfClass:[RCDFriendInfo class]] && userInfo.displayName.length > 0) {
                name = userInfo.displayName;
            }
            // //忽略大小写去判断是否包含
            if ([name rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [[RCDUtilities hanZiToPinYinWithString:name] rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [self.matchFriendList addObject:userInfo];
            }
        }
        [self sortAndRefreshWithList:self.matchFriendList];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [self resetSearchBarAndMatchFriendList];
    [self sortAndRefreshWithList:self.allFriendArray];
    [self.tableView reloadData];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    if (self.isBeginSearch == NO) {
        self.isBeginSearch = YES;
        [self.tableView reloadData];
    }
    self.searchFriendsBar.showsCancelButton = YES;
    for(UIView *view in [[[self.searchFriendsBar subviews] objectAtIndex:0] subviews]) {
        if([view isKindOfClass:[NSClassFromString(@"UINavigationButton") class]]) {
            UIButton * cancel = (UIButton *)view;
            [cancel setTitle:RCDLocalizedString(@"cancel") forState:UIControlStateNormal];
            break;
        }
    }
    return YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Private Method
- (void)setupView {
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.view.backgroundColor = [UIColor colorWithRed:235 / 255.0 green:235 / 255.0 blue:235 / 255.0 alpha:1];
    [self.view addSubview:self.tableView];
    [self.view addSubview:self.searchFriendsBar];
    [self.view addSubview:self.bottomResultView];
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.searchFriendsBar.mas_bottom);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.bottomResultView.mas_top);
    }];
    
    [self.searchFriendsBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self.view);
    }];
    
    [self.bottomResultView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view);
        make.height.offset(50 + RCDExtraBottomHeight);
    }];
    
    [self updateSelectedResult];
}

- (void)setupNavi {
    self.navigationItem.leftBarButtonItem = [[RCDUIBarButtonItem alloc] initWithLeftBarButton:RCDLocalizedString(@"back") target:self action:@selector(clickBackBtn)];
    self.navigationController.navigationBar.translucent = NO;
    self.tabBarController.navigationItem.title = RCDLocalizedString(@"contacts");
}

- (void)initData {
    self.matchFriendList = [[NSMutableArray alloc] init];
    self.resultSectionDict = [[NSDictionary alloc] init];
    self.isBeginSearch = NO;
    self.queue = dispatch_queue_create("sealtalksearch", DISPATCH_QUEUE_SERIAL);
    self.allFriendArray = [self getAllFriendList];
}

- (void)addObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSelectedResult) name:@"ReloadBottomResultView" object:nil
     ];
}

// 获取好友并且排序
- (NSArray *)getAllFriendList {
    NSMutableArray *userInfoList = [NSMutableArray arrayWithArray:[RCDUserInfoManager getAllFriends]];
    if (userInfoList.count <= 0 && !self.hasSyncFriendList) {
        [RCDDataSource syncFriendList:[RCIM sharedRCIM].currentUserInfo.userId complete:^(NSArray *result) {
            self.hasSyncFriendList = YES;
            [self sortAndRefreshWithList:result];
        }];
    }
    return userInfoList;
}

- (void)sortAndRefreshWithList:(NSArray *)friendList {
    dispatch_async(self.queue, ^{
        NSDictionary *resultDic = [[RCDUtilities sortedArrayWithPinYinDic:friendList] copy];
        self.resultKeys = resultDic[@"allKeys"];
        self.resultSectionDict = resultDic[@"infoDic"];
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    });
}

- (void)resetSearchBarAndMatchFriendList {
    _isBeginSearch = NO;
    self.searchFriendsBar.showsCancelButton = NO;
    [self.searchFriendsBar resignFirstResponder];
    self.searchFriendsBar.text = @"";
    [self.matchFriendList removeAllObjects];
}

- (void)showForwardAlertView:(NSString *)userId {
    RCConversation *conver = [[RCConversation alloc] init];
    conver.targetId = userId;
    conver.conversationType = ConversationType_PRIVATE;
    [RCDForwardManager sharedInstance].toConversation = conver;
    [[RCDForwardManager sharedInstance] showForwardAlertViewInViewController:self];
}

- (void)updateSelectedResult {
    [self.bottomResultView updateSelectResult];
}

#pragma mark - Target Action
- (void)clickBackBtn {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Getter & Setter
- (UISearchBar *)searchFriendsBar {
    if (!_searchFriendsBar) {
        _searchFriendsBar = [[UISearchBar alloc] init];
        _searchFriendsBar.delegate = self;
        _searchFriendsBar.keyboardType = UIKeyboardTypeDefault;
        _searchFriendsBar.placeholder = RCDLocalizedString(@"search");
        UIImage *searchBarBg = [RCDUtilities getImageWithColor:[UIColor clearColor] andHeight:32.0f];
        _searchFriendsBar.backgroundImage = searchBarBg;
        _searchFriendsBar.backgroundColor = HEXCOLOR(0xf0f0f6);
        
        UITextField *searchField = [_searchFriendsBar valueForKey:@"_searchField"];
        searchField.layer.borderWidth = 0.5f;
        searchField.layer.borderColor = [HEXCOLOR(0xdfdfdf) CGColor];
        searchField.layer.cornerRadius = 5.f;
    }
    return _searchFriendsBar;
}

- (RCDTableView *)tableView {
    if (!_tableView) {
        _tableView = [[RCDTableView alloc] init];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.tableFooterView = [UIView new];
        _tableView.backgroundColor = HEXCOLOR(0xf0f0f6);
        _tableView.separatorColor = HEXCOLOR(0xdfdfdf);
        _tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _tableView.bounds.size.width, 0.01f)];
        //设置右侧索引
        _tableView.sectionIndexBackgroundColor = [UIColor clearColor];
        _tableView.sectionIndexColor = HEXCOLOR(0x555555);
    }
    return _tableView;
}

- (RCDBottomResultView *)bottomResultView {
    if (!_bottomResultView) {
        _bottomResultView = [[RCDBottomResultView alloc] init];
    }
    return _bottomResultView;
}

@end