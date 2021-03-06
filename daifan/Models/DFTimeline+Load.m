#import "DFTimeline+Load.h"
#import "DFUserList.h"
#import "DFPost.h"
#import "DFServices.h"

@implementation DFTimeline (Load)

#pragma mark - Services

- (void)loadList:(LoadSuccessBlock)successBlock error:(LoadErrorBlock)errorBlock  complete:(LoadCompleteBlock)completeBlock {
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@", API_HOST, API_POSTS_PATH, API_POSTS_NEW_LIST_PARAMETER];

    NSLog(@"request: %@", urlString);

    serviceCompleteBlock serviceBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON, NSError *error) {
        NSDictionary *dict = (NSDictionary *) JSON;

        if (error) {
            NSLog(@"time line failed. \n response: %@, error: %@", response, error);
            errorBlock(error);
        } else if ([[dict objectForKey:kRESPONSE_SUCCESS] integerValue] == RESPONSE_NOT_SUCCESS) {
            errorBlock([NSError errorWithDomain:@"loadlist" code:RESPONSE_CODE_BAD_REQUEST userInfo:nil]);
        } else {
            NSLog(@"time line success.");
            NSArray *posts = [dict objectForKey:kRESPONSE_POSTS];

            NSDictionary *users = [dict objectForKey:kRESPONSE_BOOKED_USER_ID];
            [[DFUserList sharedList] mergeUserDict:users];

            [posts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                DFPost *post = [DFPost postFromDict:obj];
                [self addPost:post];
            }];

            NSLog(@"time line:%@", self);

            successBlock(posts.count);
        }

        completeBlock();
    };

    [DFServices getFromURLString:urlString completeBlock:serviceBlock];
}

- (void)pullForNew:(LoadSuccessBlock)successBlock error:(LoadErrorBlock)errorBlock  complete:(LoadCompleteBlock)completeBlock {
    NSString *newerListString = [NSString stringWithFormat:API_POSTS_NEWER_LIST_PARAMETER, self.newestPostID];
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@", API_HOST, API_POSTS_PATH, newerListString];

    NSLog(@"request: %@", urlString);

    serviceCompleteBlock serviceBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON, NSError *error) {
        NSDictionary *dict = (NSDictionary *) JSON;

        if (error) {
            NSLog(@"time line failed. \n response: %@, error: %@, JSON: %@", response, error, JSON);
            errorBlock(error);
        } else if ([[dict objectForKey:kRESPONSE_SUCCESS] integerValue] == RESPONSE_NOT_SUCCESS) {
            errorBlock([NSError errorWithDomain:@"pullfornew" code:RESPONSE_CODE_BAD_REQUEST userInfo:nil]);
        } else {
            NSLog(@"time line newer success.");
            NSArray *posts = [dict objectForKey:kRESPONSE_POSTS];

            NSUInteger newerPostCount = posts.count;

            NSDictionary *users = [dict objectForKey:kRESPONSE_BOOKED_USER_ID];
            [[DFUserList sharedList] mergeUserDict:users];

            [posts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                DFPost *post = [DFPost postFromDict:obj];
                [self addPost:post];
            }];

            NSLog(@"time line:%@", self);

            successBlock(newerPostCount);
        }

        completeBlock();
    };

    [DFServices getFromURLString:urlString completeBlock:serviceBlock];
}

- (void)loadMore:(LoadSuccessBlock)successBlock error:(LoadErrorBlock)errorBlock complete:(LoadCompleteBlock)completeBlock {
    NSString *newerListString = [NSString stringWithFormat:API_POSTS_OLDER_LIST_PARAMETER, self.oldestPostID];
    NSString *urlString = [NSString stringWithFormat:@"%@%@%@", API_HOST, API_POSTS_PATH, newerListString];

    NSLog(@"request: %@", urlString);

    serviceCompleteBlock serviceBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON, NSError *error) {
        NSDictionary *dict = (NSDictionary *) JSON;

        if (error) {
            NSLog(@"time line failed. \n response: %@, error: %@, JSON: %@", response, error, JSON);
            errorBlock(error);
        } else if ([[dict objectForKey:kRESPONSE_SUCCESS] integerValue] == RESPONSE_NOT_SUCCESS) {
            errorBlock([NSError errorWithDomain:@"loadmore" code:RESPONSE_CODE_BAD_REQUEST userInfo:nil]);
        } else {
            NSLog(@"time line older success.");
            NSArray *posts = [dict objectForKey:kRESPONSE_POSTS];

            NSDictionary *users = [dict objectForKey:kRESPONSE_BOOKED_USER_ID];
            [[DFUserList sharedList] mergeUserDict:users];

            [posts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                DFPost *post = [DFPost postFromDict:obj];
                [self addPost:post];
            }];

            NSLog(@"time line:%@", self);

            successBlock(posts.count);
        }

        completeBlock();
    };

    [DFServices getFromURLString:urlString completeBlock:serviceBlock];
}

@end