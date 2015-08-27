//
//  VDDSuplenceViewController.m
//  GimVic
//
//  Created by Vid Drobnič on 09/14/14.
//  Copyright (c) 2014 Vid Drobnič. All rights reserved.
//

#import "VDDSuplenceViewController.h"
#import "VDDSuplenceSource.h"
#import "VDDSuplenceDataFetch.h"
#import "VDDSideMenuViewController.h"
#import "VDDSideMenuTransitioner.h"
#import "VDDRootViewController.h"
#import "VDDHybridDataFetch.h"

@interface VDDSuplenceViewController () <UIScrollViewDelegate>
{
    UIScrollView *mainScrollView;
    UIScrollView *tabBarScroll;
    UITableView *tableViews[5];
    UIRefreshControl *refreshers[5];
    UILabel *dateLabels[5];
    VDDSuplenceSource *sources[5];
    
    UIButton *refreshButton;
    UIActivityIndicatorView *refreshing;
    
    id <UIViewControllerTransitioningDelegate> transitioningDelegate;
}
@end


@implementation VDDSuplenceViewController

#pragma mark - Initialization

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadViews)
                                                 name:@"VDDDataFetchComplete"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(changeDates)
                                                 name:@"VDDDatesChanged"
                                               object:nil];

    
    mainScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 60, self.view.bounds.size.width, self.view.bounds.size.height-60)];
    mainScrollView.pagingEnabled = YES;
    mainScrollView.userInteractionEnabled = YES;
    mainScrollView.showsHorizontalScrollIndicator = NO;
    mainScrollView.showsVerticalScrollIndicator = NO;
    mainScrollView.contentSize = CGSizeMake(5*self.view.bounds.size.width, self.view.bounds.size.height - 60);
    mainScrollView.delegate = self;
    mainScrollView.backgroundColor = [UIColor colorWithRed:165/255.0 green:214/255.0 blue:167/255.0 alpha:1.0];
    
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [calendar components:NSCalendarUnitWeekday fromDate:[NSDate date]];
    long weekday = components.weekday;
    if (!(weekday == 1 || weekday == 7)) {
        weekday -= 2;
        mainScrollView.contentOffset = CGPointMake(self.view.bounds.size.width * weekday, 0);
    }

    
    [self.view addSubview:mainScrollView];
    
    for (int i = 0; i < 5; i++) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = ([paths count] > 0) ? paths[0] : nil;

        int count = 0;
        
        NSDictionary *data = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/filtered-%d", documentsPath, i]];
        NSArray *keys = [data allKeys];
        for (NSString *key in keys) {
            if ([[data valueForKey:key] count] != 0) {
                count++;
            }
        }
        if (count == 0) {
            NSArray *views = [[NSBundle mainBundle] loadNibNamed:@"VDDFreeView" owner:self options:nil];
            UIView *freeView = [views lastObject];
            freeView.frame = CGRectMake(self.view.bounds.size.width * i, 0, self.view.bounds.size.width, self.view.bounds.size.height-60);
            [mainScrollView addSubview:freeView];
            continue;
        }
        
        tableViews[i] = [[UITableView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * i, 0, self.view.bounds.size.width, self.view.bounds.size.height - 60) style:UITableViewStyleGrouped];
        refreshers[i] = [[UIRefreshControl alloc] init];
        
        sources[i] = [[VDDSuplenceSource alloc] initWithIndex:i data:data numberOfSections:count];
        tableViews[i].separatorColor = [UIColor colorWithRed:67/255.0 green:160/255.0 blue:71/255.0 alpha:1.0];
        tableViews[i].dataSource = sources[i];
        tableViews[i].delegate = sources[i];
        tableViews[i].allowsSelection = NO;
        
        [refreshers[i] addTarget:self action:@selector(refresher) forControlEvents:UIControlEventValueChanged];
        [tableViews[i] addSubview:refreshers[i]];
        
        [mainScrollView addSubview:tableViews[i]];
    }

    UIView *tabBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60)];
    tabBar.backgroundColor = [UIColor colorWithRed:76/255.0 green:175/255.0 blue:80/255.0 alpha:1.0];
    [self.view addSubview:tabBar];
    
    
    UIImage *sideMenuImage = [UIImage imageNamed:@"Menu.png"];
    UIButton *button = [[UIButton alloc] init];
    [button addTarget:self action:@selector(showSideMenu) forControlEvents:UIControlEventTouchUpInside];
    [button setImage:sideMenuImage forState:UIControlStateNormal];
    button.frame = CGRectMake(20, 20, 30, 30);
    [self.view addSubview:button];
    
    
    UIImage *refreshImage = [UIImage imageNamed:@"Reload.png"];
    refreshButton = [[UIButton alloc] init];
    [refreshButton addTarget:self action:@selector(buttonRefresher) forControlEvents:UIControlEventTouchUpInside];
    [refreshButton setImage:refreshImage forState:UIControlStateNormal];
    refreshButton.frame = CGRectMake(self.view.bounds.size.width - 50, 20, 30, 30);
    [self.view addSubview:refreshButton];
    
    refreshing = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 50, 20, 30, 30)];
    refreshing.color = [UIColor colorWithRed:200/255.0 green:230/255.0 blue:201/255.0 alpha:1.0];
    [self.view addSubview:refreshing];
    [refreshing stopAnimating];
    
    
    tabBarScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(70, 20, self.view.bounds.size.width - 2*70, 30)];
    [self.view addSubview:tabBarScroll];
    tabBarScroll.userInteractionEnabled = NO;
    tabBarScroll.showsHorizontalScrollIndicator = NO;
    tabBarScroll.showsVerticalScrollIndicator = NO;
    tabBarScroll.pagingEnabled = YES;
    tabBarScroll.contentSize = CGSizeMake(5*tabBarScroll.bounds.size.width, tabBarScroll.bounds.size.height);
    weekday = components.weekday;
    if (!(weekday == 1 || weekday == 7)) {
        weekday -= 2;
        tabBarScroll.contentOffset = CGPointMake(tabBarScroll.frame.size.width * weekday, 0);
    }

    
    NSArray *weekdays = @[@"Ponedeljek", @"Torek", @"Sreda", @"Četrtek", @"Petek"];
    
    for (int i = 0; i < 5; i++) {
        dateLabels[i] = [[UILabel alloc] initWithFrame:CGRectMake(tabBarScroll.bounds.size.width * i, 0, tabBarScroll.bounds.size.width, tabBarScroll.bounds.size.height)];
        dateLabels[i].text = weekdays[i];
        dateLabels[i].textAlignment = NSTextAlignmentCenter;
        dateLabels[i].textColor = [UIColor colorWithRed:200/255.0 green:230/255.0 blue:201/255.0 alpha:1.0];
        [tabBarScroll addSubview:dateLabels[i]];
    }
}

#pragma mark - UI Actions

- (void)showSideMenu {
    VDDSideMenuViewController *sideMenu = [[VDDSideMenuViewController alloc] initWithSelectedView:VDDSuplenceView];
    sideMenu.modalPresentationStyle = UIModalPresentationCustom;
    
    transitioningDelegate = [[VDDSideMenuTransitioningDelegate alloc] init];
    sideMenu.transitioningDelegate = transitioningDelegate;
    
    [self presentViewController:sideMenu animated:YES completion:NULL];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    double percentageScrolled = scrollView.contentOffset.x / scrollView.contentSize.width;
    tabBarScroll.contentOffset = CGPointMake(tabBarScroll.contentSize.width * percentageScrolled, 0);
}

#pragma mark - Refreshing

- (void)refresher {
        [NSThread detachNewThreadSelector:@selector(refreshBoth) toTarget:self withObject:nil];
}

- (void)refreshBoth {
    if ([VDDSuplenceDataFetch sharedSuplenceDataFetch].isRefreshing == NO)
        [[VDDSuplenceDataFetch sharedSuplenceDataFetch] refresh];
    if ([VDDHybridDataFetch sharedHybridDataFetch].isRefreshing == NO)
        [[VDDHybridDataFetch sharedHybridDataFetch] refresh];
}

- (void)buttonRefresher {
    if (refreshButton.hidden == NO) {
        refreshButton.hidden = YES;
        [refreshing startAnimating];
    }
    if ([VDDSuplenceDataFetch sharedSuplenceDataFetch].isRefreshing == NO)
        [NSThread detachNewThreadSelector:@selector(refresh) toTarget:[VDDSuplenceDataFetch sharedSuplenceDataFetch] withObject:nil];
}

- (void)reloadViews {
    for (int i = 0; i < 5; i++) {
        if (refreshers[i])
            [refreshers[i] endRefreshing];
    }
    
    if (refreshing.isAnimating == YES) {
        [refreshing stopAnimating];
        refreshButton.hidden = NO;
    }
    
    NSMutableArray *subviews = [NSMutableArray arrayWithArray:mainScrollView.subviews];
    BOOL sorted = NO;
    while (!sorted) {
        sorted = YES;
        for (int i = 0; i < subviews.count-1; i++) {
            UIView *view1 = subviews[i];
            UIView *view2 = subviews[i+1];
            if (view1.frame.origin.x > view2.frame.origin.x) {
                subviews[i] = view2;
                subviews[i+1] = view1;
                sorted = NO;
            }
        }
    }

    
    for (int i = 0; i < 5; i++) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = ([paths count] > 0) ? paths[0] : nil;
        
        int count = 0;
        
        NSDictionary *data = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/filtered-%d", documentsPath, i]];
        NSArray *keys = [data allKeys];
        for (NSString *key in keys) {
            if ([[data valueForKey:key] count] != 0) {
                count++;
            }
        }
        if (count == 0) {
            [subviews[i] removeFromSuperview];
            NSArray *views = [[NSBundle mainBundle] loadNibNamed:@"VDDFreeView" owner:self options:nil];
            UIView *freeView = [views lastObject];
            freeView.frame = CGRectMake(self.view.bounds.size.width * i, 0, self.view.bounds.size.width, self.view.bounds.size.height - 60);
            [mainScrollView addSubview:freeView];
            sources[i] = nil;
            refreshers[i] = nil;
            tableViews[i] = nil;
            continue;
        }
        
        if (tableViews[i] != nil) {
            [sources[i] reloadData:data];
            [tableViews[i] reloadData];
            continue;
        }
        
        [subviews[i] removeFromSuperview];
        tableViews[i] = [[UITableView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * i, 0, self.view.bounds.size.width, self.view.bounds.size.height - 60) style:UITableViewStyleGrouped];
        refreshers[i] = [[UIRefreshControl alloc] init];
        
        sources[i] = [[VDDSuplenceSource alloc] initWithIndex:i data:data numberOfSections:count];
        tableViews[i].separatorColor = [UIColor colorWithRed:67/255.0 green:160/255.0 blue:71/255.0 alpha:1.0];
        tableViews[i].dataSource = sources[i];
        tableViews[i].delegate = sources[i];
        tableViews[i].allowsSelection = NO;
        
        [refreshers[i] addTarget:self action:@selector(refresher) forControlEvents:UIControlEventValueChanged];
        [tableViews[i] addSubview:refreshers[i]];
        
        [mainScrollView addSubview:tableViews[i]];
    }
}

#pragma mark - Miscellaneous

- (int)addOneToIndex:(int)index {
    index = index + 1;
    if (index > 6)
        index = 0;
    return index;
}

- (void)changeDates {
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [calendar components:NSCalendarUnitWeekday fromDate:[NSDate date]];
    long weekday = components.weekday;
    if (!(weekday == 1 || weekday == 7)) {
        weekday -= 2;
        mainScrollView.contentOffset = CGPointMake(self.view.bounds.size.width * weekday, 0);
        tabBarScroll.contentOffset = CGPointMake(tabBarScroll.frame.size.width * weekday, 0);
    } else {
        mainScrollView.contentOffset = CGPointMake(0, 0);
        tabBarScroll.contentOffset = CGPointMake(0, 0);
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end