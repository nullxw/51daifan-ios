#import "DFTimeLineViewController.h"
#import "DFPost.h"
#import "AFJSONRequestOperation.h"
#import "DFUserList.h"
#import "DFFooterView.h"
#import "DFUser.h"
#import "AFHTTPClient.h"
#import "DFComment.h"
#import "DFPost+Book.h"
#import "DFPost+Comment.h"
#import "TSMessage.h"

#define TIMELINE_CELL_ID @"timeLineCellIdentifier"

@implementation DFTimeLineViewController {
    ACTimeScroller *_timeScroller;

    NSMutableArray *_posts;
    DFFooterView *_footerView;

    long _newestPostID;
    long _oldestPostID;
}

- (id)init {
    self = [super init];
    if (self) {
        self.wantsFullScreenLayout = YES;

        _posts = [[NSMutableArray alloc] init];

        _newestPostID = 0;
        _oldestPostID = LONG_MAX;
    }

    return self;
}

- (void)post {
    DFPostViewController *postVC = [[DFPostViewController alloc] init];
    postVC.delegate = self;

    [self presentViewController:postVC animated:YES completion:nil];
}

- (void)loadView {
    [super loadView];

    self.tableView.separatorColor = [UIColor colorWithHexString:SEPARATOR_LINE_COLOR];
    self.tableView.allowsSelection = NO;

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"下拉刷新"];
    [self.refreshControl addTarget:self action:@selector(pullForNew) forControlEvents:UIControlEventValueChanged];

    [self.tableView registerClass:[DFTimeLineCell class] forCellReuseIdentifier:TIMELINE_CELL_ID];

//    DFCoverView *coverView = [[DFCoverView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _timelineView.frame.size.width, COVER_VIEW_HEIGHT)];
//    self.tableView.tableHeaderView = coverView;

    _footerView = [[DFFooterView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.tableView.frame.size.width, FOOTER_VIEW_HEIGHT)];
    _footerView.delegate = self;
    self.tableView.tableFooterView = _footerView;

    self.view.backgroundColor = [UIColor whiteColor];

//    _timeScroller = [[ACTimeScroller alloc] initWithDelegate:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    UIButton *postButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [postButton setImage:[UIImage imageNamed:@"post.png"] forState:UIControlStateNormal];
    [postButton addTarget:self action:@selector(post) forControlEvents:UIControlEventTouchUpInside];
    postButton.frame = CGRectMake(0.0f, 0.0f, 34.0f, 34.0f);

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:postButton];

    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"title.png"]];

    [self loadList];
}

#pragma mark - table view data source & delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    DFPost *post = [_posts objectAtIndex:(NSUInteger) indexPath.row];

    return [DFTimeLineCell heightForPost:post];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _posts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DFTimeLineCell *cell = [tableView dequeueReusableCellWithIdentifier:TIMELINE_CELL_ID];
    cell.delegate = self;

    DFPost *post = [_posts objectAtIndex:(NSUInteger) indexPath.row];
    cell.post = post;

    return cell;
}

#pragma mark - Time Scroller Delegate

- (UITableView *)tableViewForTimeScroller:(ACTimeScroller *)timeScroller {
    return self.tableView;
}

- (NSDate *)timeScroller:(ACTimeScroller *)timeScroller dateForCell:(UITableViewCell *)cell {
    if (!cell)
        return [NSDate date];

    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    DFPost *post = [_posts objectAtIndex:(NSUInteger) indexPath.row];
    return post.publishDate;
}

#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [_timeScroller scrollViewWillBeginDragging];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [_timeScroller scrollViewDidScroll];

    if (_posts.count <= 0) {
        return;
    }

    if (_oldestPostID <= 1) {
        return;
    }

    if (self.tableView.contentOffset.y > self.tableView.contentSize.height - self.tableView.frame.size.height + 10.0f) {
        if (!_footerView.isRefreshing) {
            [_footerView beginRefreshing];
        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [_timeScroller scrollViewDidEndDecelerating];
}

#pragma mark - Services

- (void)loadList {
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@", API_HOST, API_POSTS_PATH, API_POSTS_NEW_LIST_PARAMETER];

    NSLog(@"request: %@", urlString);

    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request
            success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                NSLog(@"time line success.");
                NSDictionary *dict = (NSDictionary *) JSON;

                if ([[dict objectForKey:kRESPONSE_SUCCESS] integerValue] == RESPONSE_NOT_SUCCESS) {
                    [self showErrorMessage:@"BS做服务端的同学" title:@"服务器出错了哦"];
                    return;
                }

                NSArray *posts = [dict objectForKey:kRESPONSE_POSTS];

                NSDictionary *users = [dict objectForKey:kRESPONSE_BOOKED_USER_ID];
                [[DFUserList sharedList] mergeUserDict:users];

                [posts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    DFPost *post = [DFPost postFromDict:obj];
                    [self updateIDRange:post];
                    [_posts insertOrReplaceObjectSorted:post];
                }];

                NSLog(@"time line:%@", _posts);

                [self.tableView reloadData];
                [self updateFooterViewText];

                [self showSuccessMessage:[NSString stringWithFormat:@"成功获取%d条带饭信息", posts.count]
                                   title:@"^_^"];
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                NSLog(@"time line failed. \n response: %@, error: %@, JSON: %@", response, error, JSON);
            }];
    [operation start];
}

- (void)pullForNew {
    NSString *newerListString = [NSString stringWithFormat:API_POSTS_NEWER_LIST_PARAMETER, _newestPostID];
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@", API_HOST, API_POSTS_PATH, newerListString];

    NSLog(@"request: %@", urlString);

    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request
            success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                NSLog(@"time line newer success.");
                NSDictionary *dict = (NSDictionary *) JSON;

                if ([[dict objectForKey:kRESPONSE_SUCCESS] integerValue] == RESPONSE_NOT_SUCCESS) {
                    return;
                }

                NSArray *posts = [dict objectForKey:kRESPONSE_POSTS];

                NSUInteger newerPostCount = posts.count;

                if (newerPostCount > 0) {
                    NSDictionary *users = [dict objectForKey:kRESPONSE_BOOKED_USER_ID];
                    [[DFUserList sharedList] mergeUserDict:users];

                    [posts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        DFPost *post = [DFPost postFromDict:obj];
                        [self updateIDRange:post];
                        [_posts insertOrReplaceObjectSorted:post];
                    }];

                    NSLog(@"time line:%@", _posts);

                    [self.tableView reloadData];

                    [self showSuccessMessage:[NSString stringWithFormat:@"成功取得%d条新带饭信息", newerPostCount]
                                       title:@"^_^"];
                } else {
                    [self showWarningMessage:@"暂时没有新带饭信息了哦，亲"
                                       title:@"嗯..."];
                }

                [self.refreshControl endRefreshing];
                [self updateFooterViewText];
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                NSLog(@"time line failed. \n response: %@, error: %@, JSON: %@", response, error, JSON);
            }];
    [operation start];
}

- (void)loadMore {
    NSString *newerListString = [NSString stringWithFormat:API_POSTS_OLDER_LIST_PARAMETER, _oldestPostID];
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@", API_HOST, API_POSTS_PATH, newerListString];

    NSLog(@"request: %@", urlString);

    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request
            success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                NSLog(@"time line older success.");
                NSDictionary *dict = (NSDictionary *) JSON;

                if ([[dict objectForKey:kRESPONSE_SUCCESS] integerValue] == RESPONSE_NOT_SUCCESS) {
                    return;
                }

                NSArray *posts = [dict objectForKey:kRESPONSE_POSTS];

                NSDictionary *users = [dict objectForKey:kRESPONSE_BOOKED_USER_ID];
                [[DFUserList sharedList] mergeUserDict:users];

                [posts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    DFPost *post = [DFPost postFromDict:obj];
                    [self updateIDRange:post];
                    [_posts insertOrReplaceObjectSorted:post];
                }];

                NSLog(@"time line:%@", _posts);

                [self.tableView reloadData];

                if (_oldestPostID == 1) {
                    [self showSuccessMessage:@"WOW，成功获取到最古老的带饭信息了哦"
                                       title:@"O_O"];
                } else {
                    [self showSuccessMessage:[NSString stringWithFormat:@"成功取得%d条旧的带饭信息", posts.count]
                                       title:@"^_^"];
                }

                [_footerView endRefreshing];
                [self updateFooterViewText];
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                NSLog(@"time line failed. \n response: %@, error: %@, JSON: %@", response, error, JSON);
            }];
    [operation start];
}

- (void)updateIDRange:(DFPost *)post {
    if (post.identity > _newestPostID) {
        _newestPostID = post.identity;
    }

    if (post.identity < _oldestPostID) {
        _oldestPostID = post.identity;
    }
}

- (void)updateFooterViewText {
    NSLog(@"oldest id: %ld, newest id: %ld", _oldestPostID, _newestPostID);

    if (_oldestPostID > 1) {
        [_footerView showHaveMore];
    } else {
        [_footerView showNoMore];
    }
}

#pragma mark - Book and Comment

- (void)bookOnPost:(DFPost *)post {
    [post bookOrUnbookByUser:_currentUser success:^(DFPost *post) {
        [self.tableView reloadData];
    }                  error:^(NSError *error) {
        NSLog(@"book or unbook error: %@", error);
    }];
}

- (void)commentOnPost:(DFPost *)post {
    DFPostCommentViewController *vc = [[DFPostCommentViewController alloc] init];
    vc.post = post;
    vc.delegate = self;

    [self presentViewController:vc animated:YES completion:nil];
}

#pragma Mark - post comment delegate

- (void)postComment:(NSString *)commentString toPost:(DFPost *)post {
    [post comment:commentString byUser:_currentUser success:^(DFPost *post) {
        [self.tableView reloadData];
    }       error:^(NSError *error) {

    }];
}

#pragma Mark - post delegate
- (void)post:(NSString *)postString date:(NSDate *)eatDate count:(NSInteger)totalCount {
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd";
    df.timeZone = [NSTimeZone localTimeZone];

    NSURL *url = [NSURL URLWithString:API_HOST];
    AFHTTPClient *httpClient = [AFHTTPClient clientWithBaseURL:url];

    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:3];
    [parameters setValue:[@(totalCount) stringValue] forKey:@"count"];
    [parameters setValue:[df stringFromDate:eatDate] forKey:@"eatDate"];
    [parameters setValue:postString forKey:@"name"];
    [parameters setValue:@"" forKey:@"desc"];
    [parameters setValue:[@(_currentUser.identity) stringValue] forKey:@"uid"];

    NSMutableURLRequest *postRequest = [httpClient requestWithMethod:@"POST" path:API_POST_PATH parameters:parameters];

    NSLog(@"request: %@, %@", postRequest, parameters);

    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:postRequest
            success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                if ([[(NSDictionary *) JSON objectForKey:kRESPONSE_SUCCESS] integerValue] == RESPONSE_NOT_SUCCESS) {
                    NSLog(@"post failed: %@", JSON);
                } else {
                    NSLog(@"post succeed: %@", JSON);

                    NSInteger postId = [[(NSDictionary *) JSON objectForKey:@"postid"] integerValue];

                    DFPost *post = [[DFPost alloc] init];
                    post.identity = postId;
                    post.user = _currentUser;
                    post.name = postString;
                    post.count = totalCount;
                    post.eatDate = eatDate;
                    post.publishDate = [NSDate date];

                    [self updateIDRange:post];
                    [_posts insertOrReplaceObjectSorted:post];

                    NSLog(@"time line:%@", _posts);

                    [self.tableView reloadData];
                }
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                NSLog(@"post failed in failure block: %@", JSON);
            }];

    [httpClient enqueueHTTPRequestOperation:operation];
}

#pragma mark - notification message

- (void)showSuccessMessage:(NSString *)message title:(NSString *)title {
    [TSMessage showNotificationInViewController:self.navigationController
                                      withTitle:title
                                    withMessage:message
                                       withType:TSMessageNotificationTypeSuccess
                                   withDuration:NOTIFICATION_DURATION];
}

- (void)showWarningMessage:(NSString *)message title:(NSString *)title {
    [TSMessage showNotificationInViewController:self.navigationController
                                      withTitle:title
                                    withMessage:message
                                       withType:TSMessageNotificationTypeWarning
                                   withDuration:NOTIFICATION_DURATION];
}

- (void)showErrorMessage:(NSString *)message title:(NSString *)title {
    [TSMessage showNotificationInViewController:self.navigationController
                                      withTitle:title
                                    withMessage:message
                                       withType:TSMessageNotificationTypeError
                                   withDuration:NOTIFICATION_DURATION];
}

@end