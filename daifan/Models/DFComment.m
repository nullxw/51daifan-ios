#import "DFComment.h"


@implementation DFComment {

}

+ (DFComment *)commentFromDict:(NSDictionary *)commentDict {
    DFComment *comment = [[DFComment alloc] init];
    comment.uid = [commentDict objectForKey:@"uid"];
    comment.rate = [commentDict objectForKey:@"rate"];
    comment.content = [commentDict objectForKey:@"comment"];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";

    comment.commentTime = [dateFormatter dateFromString:[commentDict objectForKey:@"commentTime"]];

    return comment;
}

+ (NSArray *)commentsFromArray:(NSArray *)commentsArray {
    NSMutableArray *comments = [[NSMutableArray alloc] initWithCapacity:commentsArray.count];

    [commentsArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [comments addObject:[DFComment commentFromDict:obj]];
    }];

    return comments;
}


@end